
from cProfile import label
from cgi import test
import sys
import numpy as np
from PNM import *
import math
import json
from ctypes import *
from dataclasses import dataclass
from matplotlib import pyplot as plt
#from matplotlib import rc


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
    plt.rc('text', usetex=True)
    plt.rc('font', family='serif')
    
    period = 20
    num_pipes = int(sys.argv[3])

    with open(sys.argv[1], "r") as log_file:
        log_data = json.load(log_file)

    test_name = sys.argv[2]
    pixel_output(log_data, test_name)
    visualise_plot(test_name, "main_mem_rd_activity",log_data,period)
    visualise_plot(test_name, "main_mem_wr_activity",log_data,period)

    for i in range(0,num_pipes):
        visualise_plot(test_name, f"tri_fifo_rd_en_{i}",log_data,period)
        visualise_plot(test_name, f"tri_fifo_wr_en_{i}",log_data,period)
        visualise_plot(test_name, f"frag_fifo_rd_en_{i}",log_data,period)
        visualise_plot(test_name, f"frag_fifo_wr_en_{i}",log_data,period)
        visualise_plot(test_name, f"t_proc_start_{i}",log_data,period)
        visualise_plot(test_name, f"t_proc_done_{i}",log_data,period)

def visualise_plot(test_name, label, log_data,period):
    # main_mem_wr_activity
    # tri_fifo_rd_en_
    # tri_fifo_wr_en_
    x_data = []
    y_data = []
    for item in log_data["sim_log"]:
        if(item["label"] == f"[{label}]"):
            y_data.append(item["data"])
            x_data.append(int(item["time"])/period)
        # if(item["label"] == "[main_mem_wr_activity]"):
        # if(item["label"] == "[tri_fifo_rd_en_]"):
        # if(item["label"] == "[tri_fifo_wr_en_]"):
    label = label.replace("_"," ")
    marker = "x"
    f = plt.figure(label)
    plt.xlabel('time (cycles)')
    plt.ylabel(label,fontsize=16)
    plt.title(label,fontsize=16)
    plt.step(x_data, y_data)

    #fig=plt.gcf()
    #fig.set_size_inches(x,y)
    plt.savefig(f"data/{test_name}/{label}.pdf", format="pdf", dpi=1200)
    plt.close()

def visualise_accumulate(label, log_data,period):
    # main_mem_wr_activity
    # tri_fifo_rd_en_
    # tri_fifo_wr_en_
    x_data = []
    y_data = []
    y_tmp = 0
    for item in log_data["sim_log"]:
        if(item["label"] == f"[{label}]"):
            y_tmp += item["data"]
            y_data.append(y_tmp)
            x_data.append(int(item["time"])/period)
        # if(item["label"] == "[main_mem_wr_activity]"):
        # if(item["label"] == "[tri_fifo_rd_en_]"):
        # if(item["label"] == "[tri_fifo_wr_en_]"):
    label = label.replace("_"," ")
    marker = "x"
    f = plt.figure(label)
    plt.xlabel('time (cycles)')
    plt.ylabel(label,fontsize=16)
    plt.title(label,fontsize=16)
    
    

    plt.step(x_data, y_data)

    #fig=plt.gcf()
    #fig.set_size_inches(x,y)
    plt.savefig(f"data/{label}.pdf", format="pdf", dpi=1200)
    f.close()
 

def pixel_output(log_data, test_name):
    res_x = 0
    res_y = 0
  
    pixels = []
    
#all time axes should be devided by 20 to be in terms of cycles
    
    pixel_attr_count = 0

    for item in log_data["sim_log"]:
        if(item["label"] == "[res_x]"):
            res_x = item["data"]
            
        if(item["label"] == "[res_y]"):
            res_y = item["data"]

        if(item["label"] == "[Total_Cycles]"):
            cycles = item["data"]
            print(f"Total Cycles taken: {cycles}")

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
                    print(x,y)
                    pixels.append(Pixel(x,y,z,r,g,b,s,t))
    screen = np.zeros(shape=(res_y, res_x, 3), dtype=np.float32)
    print(f"resolution: {res_x} x {res_y}")
    for pix in pixels:
        #pix.display()
        screen[pix.y,pix.x,0] = pix.r
        screen[pix.y,pix.x,1] = pix.g
        screen[pix.y,pix.x,2] = pix.b


            
    #write_pfm(screen, f'data/triRender.pfm')
    writePFMtoPPM(f'renders/{test_name}', screen, res_y, res_x)

def hexstr2float(s):
    i = int(s, 16)                   # convert from hex to a Python int
    cp = pointer(c_int(i))           # make this into a c integer
    fp = cast(cp, POINTER(c_float))  # cast the int pointer to a float pointer
    return fp.contents.value         # dereference the pointer, get the float
    
def writePFMtoPPM(name, PFM, height, width, gc = False, scaling = False):
    PPM = np.empty(shape=(height,width, 3), dtype=np.float32)  
    write_pfm(PFM,  f'{name}.pfm')
    #PFM = clampLowerUpper(PFM, 0, 1)

    print(PFM.max(), PFM.min())    

    for y in range(height):
        for x in range(width):
        
            PPM[y,x,:] = PFM[y,x,:] * 255
    if scaling:
        PPM = PPM # call scaling function
    if gc:
        PPM = gammaCorrect(1.1, PPM, height, width)
    write_ppm(PPM.astype(np.uint8), f'{name}.ppm')


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



