//[header]
// A practical implementation of the rasterization algorithm.
//[/header]
//[compile]
// Download the raster3d.cpp, cow.h and geometry.h files to the same folder.
// Open a shell/terminal, and run the following command where the files are saved:
//
// c++ -o raster3d raster3d.cpp  -std=c++11 -O3
//
// Run with: ./raster3d. Open the file ./output.png in Photoshop or any program
// reading PPM files.
//[/compile]
//[ignore]
// Copyright (C) 2012  www.scratchapixel.com
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//[/ignore]

#include "geometry.h"
#include <fstream>
#include <chrono>

#include "cow.h"

static const float inchToMm = 25.4;
enum FitResolutionGate { kFill = 0, kOverscan };
typedef float coordinatePrecision;
typedef float depthBufferPrecision;
//[comment]
// Compute screen coordinates based on a physically-based camera model
// http://www.scratchapixel.com/lessons/3d-basic-rendering/3d-viewing-pinhole-camera
//[/comment]
void computeScreenCoordinates(
    const float &filmApertureWidth,
    const float &filmApertureHeight,
    const uint32_t &imageWidth,
    const uint32_t &imageHeight,
    const FitResolutionGate &fitFilm,
    const float &nearClippingPLane,
    const float &focalLength,
    float &top, float &bottom, float &left, float &right
)
{
    float filmAspectRatio = filmApertureWidth / filmApertureHeight;
    float deviceAspectRatio = imageWidth / (float)imageHeight;
    
    top = ((filmApertureHeight * inchToMm / 2) / focalLength) * nearClippingPLane;
    right = ((filmApertureWidth * inchToMm / 2) / focalLength) * nearClippingPLane;

    // field of view (horizontal)
    float fov = 2 * 180 / M_PI * atan((filmApertureWidth * inchToMm / 2) / focalLength);
    std::cerr << "Field of view " << fov << std::endl;
    
    float xscale = 1;
    float yscale = 1;
    
    switch (fitFilm) {
        default:
        case kFill:
            if (filmAspectRatio > deviceAspectRatio) {
                xscale = deviceAspectRatio / filmAspectRatio;
            }
            else {
                yscale = filmAspectRatio / deviceAspectRatio;
            }
            break;
        case kOverscan:
            if (filmAspectRatio > deviceAspectRatio) {
                yscale = filmAspectRatio / deviceAspectRatio;
            }
            else {
                xscale = deviceAspectRatio / filmAspectRatio;
            }
            break;
    }
    
    right *= xscale;
    top *= yscale;
    
    bottom = -top;
    left = -right;
}

//[comment]
// Compute vertex raster screen coordinates.
// Vertices are defined in world space. They are then converted to camera space,
// then to NDC space (in the range [-1,1]) and then to raster space.
// The z-coordinates of the vertex in raster space is set with the z-coordinate
// of the vertex in camera space.
//[/comment]


float min3(const float &a, const float &b, const float &c)
{ return std::min(a, std::min(b, c)); }

float max3(const float &a, const float &b, const float &c)
{ return std::max(a, std::max(b, c)); }

float edgeFunction(const Vec3f &a, const Vec3f &b, const Vec3f &c)
{ return (c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0]); }

#include "rasterTriangle.h"


int main(int argc, char **argv)
{
    const uint32_t imageWidth = 1920; //640;
    const uint32_t imageHeight = 1080;// 480;
    const Matrix44f worldToCamera = {0.707107, -0.331295, 0.624695, 0, 0, 0.883452, 0.468521, 0, -0.707107, -0.331295, 0.624695, 0, -1.63871, -5.747777, -40.400412, 1};

    const uint32_t ntris = 3156;
    const float nearClippingPLane = 1;
    const float farClippingPLane = 1000;
    float focalLength = 20; // in mm
    // 35mm Full Aperture in inches
    float filmApertureWidth = 0.980;
    float filmApertureHeight = 0.735;

    Matrix44f cameraToWorld = worldToCamera.inverse();

    // compute screen coordinates
    float t, b, l, r; //top, bottom, left, right of screen
    
    computeScreenCoordinates(
        filmApertureWidth, filmApertureHeight,
        imageWidth, imageHeight,
        kOverscan,
        nearClippingPLane,
        focalLength,
        t, b, l, r);
    
    // define the frame-buffer and the depth-buffer. Initialize depth buffer
    // to far clipping plane.
    Vec3<unsigned char> *frameBuffer = new Vec3<unsigned char>[imageWidth * imageHeight];
    for (uint32_t i = 0; i < imageWidth * imageHeight; ++i) frameBuffer[i] = Vec3<unsigned char>(255);
    float *depthBuffer = new float[imageWidth * imageHeight];
    for (uint32_t i = 0; i < imageWidth * imageHeight; ++i) depthBuffer[i] = farClippingPLane;

    auto t_start = std::chrono::high_resolution_clock::now();
    
    rasterise(  nvertices, 
                stindices, 
                vertices, 
                st, 
                frameBuffer, 
                depthBuffer, 
                ntris, 
                imageHeight, 
                imageWidth, 
                worldToCamera, 
                nearClippingPLane, 
                farClippingPLane, 
                l, 
                r, 
                t, 
                b);
    
    auto t_end = std::chrono::high_resolution_clock::now();
	auto passedTime = std::chrono::duration<double, std::milli>(t_end - t_start).count();
	std::cerr << "Wall passed time:  " << passedTime << " ms" << std::endl;
    
    // [comment]
    // Store the result of the framebuffer to a PPM file (Photoshop reads PPM files).
    // [/comment]
    std::ofstream ofs;
    ofs.open("./output.ppm");
    ofs << "P6\n" << imageWidth << " " << imageHeight << "\n255\n";
    ofs.write((char*)frameBuffer, imageWidth * imageWidth * 3);
    ofs.close();
    
    delete [] frameBuffer;
    delete [] depthBuffer;
    
    return 0;
}