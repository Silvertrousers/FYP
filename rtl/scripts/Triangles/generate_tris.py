import numpy as np
import matplotlib.pyplot as plt
from scipy.spatial import Delaunay
import argparse
from skimage import filters, morphology, color

import pandas as pd


def get_triangle_colour(triangles, image, agg_func=np.median):
    """
    Get's the colour of a triangle, based on applying agg_func to the pixels
    under it
    :param triangles: scipy.spatial.Delaunay
    :param image: image as array
    :param agg_func: function
    :return: colour list
    """
    # create a list of all pixel coordinates
    ymax, xmax = image.shape[:2]
    xx, yy = np.meshgrid(np.arange(xmax), np.arange(ymax))
    pixel_coords = np.c_[xx.ravel(), yy.ravel()]

    # for each pixel, identify which triangle it belongs to
    triangles_for_coord = triangles.find_simplex(pixel_coords)

    df = pd.DataFrame({
        "triangle": triangles_for_coord,
        "r": image.reshape(-1, 3)[:, 0],
        "g": image.reshape(-1, 3)[:, 1],
        "b": image.reshape(-1, 3)[:, 2]
    })

    n_triangles = triangles.vertices.shape[0]

    by_triangle = (
        df
            .groupby("triangle")
        [["r", "g", "b"]]
            .aggregate(agg_func)
            .reindex(range(n_triangles), fill_value=0)
        # some triangles might not have pixels in them
    )

    return by_triangle.values / 256


def gaussian_mask(x, y, shape, amp=1, sigma=15):
    """
    Returns an array of shape, with values based on

    amp * exp(-((i-x)**2 +(j-y)**2) / (2 * sigma ** 2))

    :param x: float
    :param y: float
    :param shape: tuple
    :param amp: float
    :param sigma: float
    :return: array
    """
    xv, yv = np.meshgrid(np.arange(shape[1]), np.arange(shape[0]))
    g = amp * np.exp(-((xv - x) ** 2 + (yv - y) ** 2) / (2 * sigma ** 2))
    return g


def default(value, default_value):
    """
    Returns default_value if value is None, value otherwise
    """
    if value is None:
        return default_value
    return value


def edge_points(image, length_scale=200,
                n_horizontal_points=None,
                n_vertical_points=None):
    """
    Returns points around the edge of an image.
    :param image: image array
    :param length_scale: how far to space out the points if no
                         fixed number of points is given
    :param n_horizontal_points: number of points on the horizonal edge.
                                Leave as None to use lengthscale to determine
                                the value
    :param n_vertical_points: number of points on the horizonal edge.
                                Leave as None to use lengthscale to determine
                                the value
    :return: array of coordinates
    """
    ymax, xmax = image.shape[:2]

    if n_horizontal_points is None:
        n_horizontal_points = int(xmax / length_scale)

    if n_vertical_points is None:
        n_vertical_points = int(ymax / length_scale)

    delta_x = xmax / n_horizontal_points
    delta_y = ymax / n_vertical_points

    return np.array(
        [[0, 0], [xmax, 0], [0, ymax], [xmax, ymax]]
        + [[delta_x * i, 0] for i in range(1, n_horizontal_points)]
        + [[delta_x * i, ymax] for i in range(1, n_horizontal_points)]
        + [[0, delta_y * i] for i in range(1, n_vertical_points)]
        + [[xmax, delta_y * i] for i in range(1, n_vertical_points)]
    )


def generate_uniform_random_points(image, n_points=100):
    """
    Generates a set of uniformly distributed points over the area of image
    :param image: image as an array
    :param n_points: int number of points to generate
    :return: array of points
    """
    ymax, xmax = image.shape[:2]
    points = np.random.uniform(size=(n_points, 2))
    points *= np.array([xmax, ymax])
    points = np.concatenate([points, edge_points(image)])
    return points


def generate_max_entropy_points(image, n_points=100,
                                entropy_width=None,
                                filter_width=None,
                                suppression_width=None,
                                suppression_amplitude=None):
    """
    Generates a set of points over the area of image, using maximum entropy
    to guess which points are importance. All length scales are relative to the
    density of the points.
    :param image: image as an array
    :param n_points: int number of points to generate:
    :param entropy_width: width over which to measure entropy
    :param filter_width: width over which to pre filter entropy
    :param suppression_width: length for suppressing entropy before choosing the
                              next point.
    :param suppression_amplitude: amplitude to suppress entropy before choosing the
                              next point.
    :return:
    """
    # calculate length scale
    ymax, xmax = image.shape[:2]
    length_scale = np.sqrt(xmax*ymax / n_points)
    entropy_width = length_scale * default(entropy_width, 0.2)
    filter_width = length_scale * default(filter_width, 0.1)
    suppression_width = length_scale * default(suppression_width, 0.3)
    suppression_amplitude = default(suppression_amplitude, 3)

    # convert to grayscale
    im2 = color.rgb2gray(image)

    # filter
    im2 = (
        255 * filters.gaussian(im2, sigma=filter_width, multichannel=True)
    ).astype("uint8")

    # calculate entropy
    im2 = filters.rank.entropy(im2, morphology.disk(entropy_width))

    points = []
    for _ in range(n_points):
        y, x = np.unravel_index(np.argmax(im2), im2.shape)
        im2 -= gaussian_mask(x, y,
                             shape=im2.shape[:2],
                             amp=suppression_amplitude,
                             sigma=suppression_width)
        points.append((x, y))

    points = np.array(points)
    return points


def get_tris(input_path, n_points):
    image = plt.imread(input_path)
    points = generate_max_entropy_points(image, n_points=n_points)
    points = np.concatenate([points, edge_points(image)])

    tri = Delaunay(points)

    fig, ax = plt.subplots()
    ax.invert_yaxis()
    triangle_colours = get_triangle_colour(tri, image)
    return tri.points, tri.vertices, triangle_colours

def sort_tris(points, vertices, colours):
    vertices = np.copy(vertices)
    for i, idxs in enumerate(vertices):
        tri = points[idxs]
        orient_mat = np.hstack( (np.ones((3,1)), tri) )
        is_cw = (np.linalg.det(orient_mat) < 0)
        if not is_cw:
            vertices[i] = np.array([idxs[0], idxs[2], idxs[1]])
    return points, vertices, colours

def add_z(points):
    return np.hstack((points, np.zeros((len(points), 1))))

def gen_tris(filepath, n):
    tri = get_tris(filepath, n)
    points, indices, colours = sort_tris(*tri)
    points = add_z(points)
    vertices = []
    for i in range(0, len(vertices)):
        vertex = np.concatenate([points[i], colours[i], np.array([345])])
        vertices.append(vertex)
    return vertices, indices
    

if __name__ == "__main__":
    main()