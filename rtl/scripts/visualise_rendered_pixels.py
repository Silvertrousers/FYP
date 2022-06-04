
from cProfile import label
import sys
import numpy as np
from PNM import *
import math
import json
from ctypes import *
from dataclasses import dataclass

@dataclass
class Pixel:
    x: int
    y: int
    z: float
    r: float
    g: float
    b: float
    s: float
    t: float

    def display(self):
        """displays the pixel in xyz rgb format"""
        print(f"x,y,z:({self.x},{self.y},{self.z}),  r,g,b:{self.r},{self.g},{self.b}")

# The following is a command to run a top sim
#iverilog -o top_Test -c file_list.txt -I src/hardfloat_veri/ -v -D THREE_TRI_HANDWRITTEN_STRIP -D PIPE_2 -s top_Test; vvp top_Test > run_log.txt

def main():
    res_x = 0
    res_y = 0
  
    pixels = []
    

    
    
    with open('run_log.txt', "r") as log_file:
        log_data = json.load(log_file)

    pixel_attr_count = 0

    for item in log_data["sim_log"]:
        if(item["label"] == "[res_x]"):
            res_x = item["data"]
            
        if(item["label"] == "[res_y]"):
            res_y = item["data"]

        if(item["label"] == "[frag_mem_write]"):
            if(item["data"][1] != "0xxxxxxxxx"):
                
                pixel_attr_count += 1
                if(pixel_attr_count == 1):
                    #print(item)
                    
                    x = int(item["data"][1], 16)
                    #print(x)
                if(pixel_attr_count == 2):
                    y = int(item["data"][1], 16)
                if(pixel_attr_count == 3):
                    z = hexstr2float(item["data"][1])
                if(pixel_attr_count == 4):
                    r = hexstr2float(item["data"][1])
                if(pixel_attr_count == 5):
                    g = hexstr2float(item["data"][1])
                if(pixel_attr_count == 6):
                    b = hexstr2float(item["data"][1])
                if(pixel_attr_count == 7):
                    s = hexstr2float(item["data"][1])
                if(pixel_attr_count == 8):
                    t = hexstr2float(item["data"][1])
                    pixel_attr_count = 0
                    pixels.append(Pixel(x,y,z,r,g,b,s,t))
    screen = np.zeros(shape=(res_y, res_x, 3), dtype=np.float32)
    print(f"resolution: {res_x} x {res_y}")
    for pix in pixels:
        #pix.display()
        screen[pix.y,pix.x,0] = pix.r
        screen[pix.y,pix.x,1] = pix.g
        screen[pix.y,pix.x,2] = pix.b


            
    #write_pfm(screen, f'data/triRender.pfm')
    writePFMtoPPM(f'triRender', screen, res_y, res_x)
   

def hexstr2float(s):
    i = int(s, 16)                   # convert from hex to a Python int
    cp = pointer(c_int(i))           # make this into a c integer
    fp = cast(cp, POINTER(c_float))  # cast the int pointer to a float pointer
    return fp.contents.value         # dereference the pointer, get the float
    
def writePFMtoPPM(name, PFM, height, width, gc = False, scaling = False):
    PPM = np.empty(shape=(height,width, 3), dtype=np.float32)  
    write_pfm(PFM,  f'data/{name}.pfm')
    #PFM = clampLowerUpper(PFM, 0, 1)

    print(PFM.max(), PFM.min())    

    for y in range(height):
        for x in range(width):
        
            PPM[y,x,:] = PFM[y,x,:] * 255
    if scaling:
        PPM = PPM # call scaling function
    if gc:
        PPM = gammaCorrect(1.1, PPM, height, width)
    write_ppm(PPM.astype(np.uint8), f'data/{name}.ppm')


def drawVerticalLine(image, x, yMax, yMin, colour):
    for y_pixel in range(yMin, yMax):
        for x_pixel in range(x - 1, x + 1):
            image[y_pixel, x_pixel, :] = colour

    return image

def drawHorizLine(image, y, xMax, xMin, colour):
    for x_pixel in range(xMin, xMax):
        for y_pixel in range(y - 1, y + 1):
            image[y_pixel, x_pixel, :] = colour

    return image

def clampLowerUpper(m, lower, upper):
    height,width,_ = m.shape
    for y in range(height):
        for x in range(width):
            for z in range(0, len(m[y,x,:])-1):
                if(m[y,x,z] > upper):
                    m[y,x,z] = upper
                if(m[y,x,z] < lower):
                    m[y,x,z] = lower
            
    return m

if '__main__' == __name__:
    main()
