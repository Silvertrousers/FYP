
void rasterise(uint32_t *nvertices, 
               uint32_t *stindices, 
               Vec3f *vertices, 
               Vec2f *st, 
               Vec3<unsigned char> *frameBuffer, 
               float *depthBuffer, 
               const uint32_t ntris, 
               const uint32_t imageHeight,
               const uint32_t imageWidth,
               const Matrix44f worldToCamera,
               const float nearClippingPLane,
               const float farClippingPLane,
               float l, 
               float r, 
               float t,  
               float b
){    
    // Outer loop
    
    for (uint32_t i = 0; i < ntris; ++i) {
        const Vec3f &v0 = vertices[nvertices[i * 3]];
        const Vec3f &v1 = vertices[nvertices[i * 3 + 1]];
        const Vec3f &v2 = vertices[nvertices[i * 3 + 2]];
        
        
        // Convert the vertices of the triangle to raster space
        
        Vec3f v0Raster, v1Raster, v2Raster;
        convertToRaster(v0, worldToCamera, l, r, t, b, nearClippingPLane, imageWidth, imageHeight, v0Raster);
        convertToRaster(v1, worldToCamera, l, r, t, b, nearClippingPLane, imageWidth, imageHeight, v1Raster);
        convertToRaster(v2, worldToCamera, l, r, t, b, nearClippingPLane, imageWidth, imageHeight, v2Raster);
        
        
        // Precompute reciprocal of vertex z-coordinate
        
        v0Raster.z = 1 / v0Raster.z,
        v1Raster.z = 1 / v1Raster.z,
        v2Raster.z = 1 / v2Raster.z;
        
        
        
        // Prepare vertex attributes. Divde them by their vertex z-coordinate
        // (though we use a multiplication here because v.z = 1 / v.z)
        
        Vec2f st0 = st[stindices[i * 3]];
        Vec2f st1 = st[stindices[i * 3 + 1]];
        Vec2f st2 = st[stindices[i * 3 + 2]];

        st0 *= v0Raster.z, st1 *= v1Raster.z, st2 *= v2Raster.z;
    
        float xmin = min3(v0Raster.x, v1Raster.x, v2Raster.x);
        float ymin = min3(v0Raster.y, v1Raster.y, v2Raster.y);
        float xmax = max3(v0Raster.x, v1Raster.x, v2Raster.x);
        float ymax = max3(v0Raster.y, v1Raster.y, v2Raster.y);
        
        // the triangle is out of screen
        if (xmin > imageWidth - 1 || xmax < 0 || ymin > imageHeight - 1 || ymax < 0) continue;

        // be careful xmin/xmax/ymin/ymax can be negative. Don't cast to uint32_t
        uint32_t x0 = std::max(int32_t(0), (int32_t)(std::floor(xmin)));
        uint32_t x1 = std::min(int32_t(imageWidth) - 1, (int32_t)(std::floor(xmax)));
        uint32_t y0 = std::max(int32_t(0), (int32_t)(std::floor(ymin)));
        uint32_t y1 = std::min(int32_t(imageHeight) - 1, (int32_t)(std::floor(ymax)));

        float area = edgeFunction(v0Raster, v1Raster, v2Raster);
        
        //what conventions are we using for screen pace coordinates, does OpenGL have a convention?
        // Inner loop
        
        for (uint32_t y = y0; y <= y1; ++y) {
            for (uint32_t x = x0; x <= x1; ++x) {
                Vec3f pixelSample(x + 0.5, y + 0.5, 0);
                float w0 = edgeFunction(v1Raster, v2Raster, pixelSample);
                float w1 = edgeFunction(v2Raster, v0Raster, pixelSample);
                float w2 = edgeFunction(v0Raster, v1Raster, pixelSample);
                if (w0 >= 0 && w1 >= 0 && w2 >= 0) {
                    w0 /= area;
                    w1 /= area;
                    w2 /= area;
                    float oneOverZ = v0Raster.z * w0 + v1Raster.z * w1 + v2Raster.z * w2;
                    float z = 1 / oneOverZ;
                    
                    // Depth-buffer test
                    
                    if (z < depthBuffer[y * imageWidth + x]) {
                        depthBuffer[y * imageWidth + x] = z;
                        
                        Vec2f st = st0 * w0 + st1 * w1 + st2 * w2;
                        
                        st *= z;
                        
                        
                        // If you need to compute the actual position of the shaded
                        // point in camera space. Proceed like with the other vertex attribute.
                        // Divide the point coordinates by the vertex z-coordinate then
                        // interpolate using barycentric coordinates and finally multiply
                        // by sample depth.
                        
                        Vec3f v0Cam, v1Cam, v2Cam;
                        worldToCamera.multVecMatrix(v0, v0Cam);
                        worldToCamera.multVecMatrix(v1, v1Cam);
                        worldToCamera.multVecMatrix(v2, v2Cam);
                        
                        float px = (v0Cam.x/-v0Cam.z) * w0 + (v1Cam.x/-v1Cam.z) * w1 + (v2Cam.x/-v2Cam.z) * w2;
                        float py = (v0Cam.y/-v0Cam.z) * w0 + (v1Cam.y/-v1Cam.z) * w1 + (v2Cam.y/-v2Cam.z) * w2;
                        
                        Vec3f pt(px * z, py * z, -z); // pt is in camera space
                        
                        
                        // Compute the face normal which is used for a simple facing ratio.
                        // Keep in mind that we are doing all calculation in camera space.
                        // Thus the view direction can be computed as the point on the object
                        // in camera space minus Vec3f(0), the position of the camera in camera
                        // space.
                        
                        Vec3f n = (v1Cam - v0Cam).crossProduct(v2Cam - v0Cam);
                        n.normalize();
                        Vec3f viewDirection = -pt;
                        viewDirection.normalize();
                        
                        float nDotView =  std::max(0.f, n.dotProduct(viewDirection));
                        
                        
                        // The final color is the reuslt of the faction ration multiplied by the
                        // checkerboard pattern.
                        
                        const int M = 10;
                        float checker = (fmod(st.x * M, 1.0) > 0.5) ^ (fmod(st.y * M, 1.0) < 0.5);
                        float c = 0.3 * (1 - checker) + 0.7 * checker;
                        nDotView *= c;
                        frameBuffer[y * imageWidth + x].x = nDotView * 255;
                        frameBuffer[y * imageWidth + x].y = nDotView * 255;
                        frameBuffer[y * imageWidth + x].z = nDotView * 255;
                    }
                }
            }
        }
    }
}

// float edgeFunction(const Vec3f &a, const Vec3f &b, const Vec3f &c)
// { return (c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0]); }

// void OpenGL_rasterize(Triangle triangle){
//     //Orthographic projection
//     Vertex v0, v1, v2

//     //Construct bounding box

//     // xMin, yMax --------- xMax, yMax
//     //            |       |
//     //            |       |
//     //            |       |
//     // xMin, yMin --------- xMax, yMin

//     float xMin, yMin, xMax, yMax;
    
//     xMax = max(max(v0.x, v1.x), v2.x); 
//     xMin = min(min(v0.x, v1.x), v2.x); 
//     yMin = max(max(v0.y, v1.y), v2.y); 
//     yMax = min(min(v0.y, v1.y), v2.y); 
    
//     //Clip bounding box to screen limits

    
//     //for pixels in bounding box
//     for (uint32_t y = y0; y <= y1; ++y) {
//             for (uint32_t x = x0; x <= x1; ++x) {

//                 Fragment pixelSample(x + 0.5, y + 0.5);
//                 float w0 = edgeFunction(v1Raster, v2Raster, pixelSample);
//                 float w1 = edgeFunction(v2Raster, v0Raster, pixelSample);
//                 float w2 = edgeFunction(v0Raster, v1Raster, pixelSample);
//         //point sampling
//             //calculate coverage for anti aliasing
//         //interpoltion of depth
//             //do aa with coverage value
//         //interpolation of arbitrary vertex attributes
//             //do aa with coverage value 
//         //Create Fragment buffer, just an array of fragments?
// }

// only output is a a set of fragments

