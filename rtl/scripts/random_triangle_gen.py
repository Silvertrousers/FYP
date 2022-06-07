# from termios import VT0
# from turtle import Vec2D


# generate clockwise triangle = 
# v0, v1, v2

# random place for triangle, so generate random v0
# generate in clockwise winding order
# generate for t strip and for individual triangles

from re import I
import numpy as np 
import matplotlib.pyplot as plt
from numpy.random import seed
from numpy.random import rand
from cProfile import label
from re import S
import sys
import numpy as np
from PNM import *
import math
import json
from ctypes import *
from dataclasses import dataclass
from plyfile import PlyData, PlyElement
import struct

def main():
    if(len(sys.argv) > 1):
        res_x = int(sys.argv[1])
        res_y = int(sys.argv[2])
        num_tris = int(sys.argv[3])
        storage_format = sys.argv[4]
        size = int(sys.argv[5])
        measure = f"{sys.argv[6]}"
        synthesize = sys.argv[7]
        simulate = sys.argv[8]
    else:
        res_x = 1920
        res_y = 1080
        num_tris = 1
        storage_format = "individual"
        size = 500
        measure = "MEASURE"
        synthesize = "NO"
        simulate = "NO"

    vertex_data, index_data = triangle_gen(res_x, res_y, num_tris, storage_format, size)
    # test_stim_file = open("scripts/generate_top_test_components/three_tri_handwritten_strip.txt", "r")
    # test_stim = test_stim_file.read()
    # test_stim_file.close()
    test_stim = generate_verilog(vertex_data, index_data, res_x, res_y)
    top_test_gen_code = top_test_gen(test_stim, num_tris)

    top_test_file = open("gen/top_test_gen.v", "w")
    top_test_file.write(top_test_gen_code)
    top_test_file.close()

    define_list = f"-D {measure}"
    # if(synthesize == "SYNTH"):
    #     os.system(f"iverilog -o top_test_gen -c file_list.txt -I src/hardfloat_veri/ -v {define_list} -s top_test_gen")
    #     if(simulate == "SIM"):    
    #         os.system(f"vvp top_test_gen > run_log.txt")
            



def triangle_gen(res_x, res_y, num_tris, storage_format, size):
    x_array = []
    y_array = []
    i_array = []
    z0,z1,z2 = 1,1,1
    seed(132)#

    if(storage_format == "individual"):
        for i in range(0,num_tris):
            # choose random location by setting v0 to random place
            x0 = rand()*res_x
            y0 = rand()*res_y
            # generate a random number in the range -1,1, size is a distance parameter
            x1 = x0 + (rand() * size)
            y1 = y0 + ((rand() * 2) - 1) * size
            #if these conditions are flipped you make anticlockwise ones
            if(y1>y0):
                x2 = x0 + (rand() * size) # x0 or more
            if(y1<=y0):
                x2 = x1 - (rand() * size) # x1 or less
                
            
            y2 = min(y0,y1) - (rand() * size)
            
            x_array += [[x0,y0,z0,1,0,0,345],[x1,y1,z1,0,1,0,345],[x2,y2,z2,0,0,1,345]]
            y_array += [(1,0,0),(0,1,0),(0,0,1)]
            i_array += [i,i+1,i+2]
        #completely random colours and attributes


        #X = np.array([[1,1], [2,2.5], [3, 1], [8, 7.5], [7, 9], [9, 9]])
        print(x_array)
        X = np.array(x_array)
        Y = y_array
        plt.figure()
        plt.scatter(X[:, 0], X[:, 1], s = 70, color = X[:, 3:6])

        for i in range(0,num_tris):
            t = plt.Polygon(X[3*i:3*(i+1),0:2])
            plt.gca().add_patch(t)


        plt.show()

    if(storage_format == "strip"):
        # choose random location by setting v0 to random place
        x0 = rand()*res_x
        y0 = rand()*res_y
        # generate a random number in the range -1,1, size is a distance parameter
        x1 = x0 + (rand() * size)
        y1 = y0 + ((rand() * 2) - 1) * size
        #if these conditions are flipped you make anticlockwise ones
        if(y1>y0):
            x2 = x0 + (rand() * size) # x0 or more
        if(y1<=y0):
            x2 = x1 - (rand() * size) # x1 or less
        y2 = min(y0,y1) - (rand() * size)
            
        x_array += [[x0,y0,z0,1,0,0,345],[x1,y1,z1,0,1,0,345],[x2,y2,z2,0,0,1,345]]
        y_array += [(1,0,0),(0,1,0),(0,0,1)]
        i_array += [0,1,2]

        for i in range(0,num_tris-1):
                

            x0,y0 = x1,y1
            x1,y1 = x2,y2
            x2 = max(x0,x1) + (rand() * size) # x0 or more
            # if(y1>y0):
            #     x2 = x0 + (rand() * size) # x0 or more
            # if(y1<=y0):
            #     x2 = x1 - (rand() * size) # x1 or less
            y2 = min(y0,y1) - (rand() * size)
                
            if(i%3 == 0):
                r,g,b = 1,0,0
            if(i%3 == 1):
                r,g,b = 0,1,0
            if(i%3 == 2):    
                r,g,b = 0,0,1
            x_array += [[x2,y2,z2,r,g,b,345]]
            y_array += (r,g,b)
            i_array += [i+3]
            
            
        #completely random colours and attributes


        #X = np.array([[1,1], [2,2.5], [3, 1], [8, 7.5], [7, 9], [9, 9]])
        
        X = np.array(x_array)
        Y = y_array
        plt.figure()
        print(X)
        plt.scatter(X[:, 0], X[:, 1], s = 70, color = X[:, 3:6])

        t = plt.Polygon(X[:3,0:2])
        plt.gca().add_patch(t)

        for i in range(1,num_tris):
            t = plt.Polygon(X[i:i+3,0:2])
            plt.gca().add_patch(t)


        plt.show()
    return x_array, i_array
    
def generate_verilog(vertex_data, index_data, res_x, res_y):
    i_array_ptr = 0
    v_array_ptr = 0
    f_array_ptr = 0    

    index_addr_counter = 0
    index_verilog_code = ""
    for i in index_data:
        
        attr_write_str = f"tri_mem_wr_data = 'h{hex(i)[(-1*len(hex(i))+2):]};\n"  
        
        addr_write_str = f"tri_mem_wr_addr = 'd{i_array_ptr + index_addr_counter};\n#(PERIOD);\n"
        index_addr_counter += 1
        index_verilog_code = f"{index_verilog_code}{attr_write_str}{addr_write_str}"

    v_array_ptr = i_array_ptr + index_addr_counter
    vertex_addr_counter = 0
    vertex_verilog_code = ""
    for vertex in vertex_data:
        v = vertex
        
        print(v)
        for attr_num in range(0,len(v)):
        
            attr = v[attr_num]

            attr_write_str = f"tri_mem_wr_data = 'h{float_to_hex(attr)[(-1*len(float_to_hex(attr))+2):]};\n"  
            print(f"{attr} converted to {float_to_hex(attr)}")
            addr_write_str = f"tri_mem_wr_addr = 'd{v_array_ptr + vertex_addr_counter};\n#(PERIOD);\n"
            vertex_addr_counter += 1
            vertex_verilog_code = f"{vertex_verilog_code}{attr_write_str}{addr_write_str}"
        
        attr_write_str = "tri_mem_wr_data = 'h123;\n"  
        addr_write_str = f"tri_mem_wr_addr = 'd{v_array_ptr + vertex_addr_counter};\n#(PERIOD);\n"
        vertex_addr_counter += 1
        vertex_verilog_code = f"{vertex_verilog_code}{attr_write_str}{addr_write_str}"
    
    f_array_ptr = v_array_ptr + vertex_addr_counter + 1

    ptr_verilog_code = f"i_array_ptr = I_ARRAY_PTR;\nv_array_ptr = V_ARRAY_PTR;\nf_array_ptr = F_ARRAY_PTR;\n#PERIOD;\ntri_mem_wr_en = 1'b1;\n"

    verilog_code = ""
    num_triangles_verilog_code = f"ctrl_reg1[15:0] = TOTAL_NUM_TRIS;\n"
    resolution_verilog_code = f"res_reg[31:16] = RESX;\nres_reg[15:0] = RESY;\n"
    verilog_code = f"{num_triangles_verilog_code}{resolution_verilog_code}{ptr_verilog_code}{index_verilog_code}{vertex_verilog_code}"
    return verilog_code
        # i_array_ptr = I_AR

def top_test_gen(Test_stim, total_num_tris = 1):

    data_width = 32
    main_mem_addr_width = 32
    local_vertex_mem_addr_width = 3 
    cycles_wait_for_recieve= 1
    main_mem_cycles_wait_for_recieve = 0

    fifo_max_frags = 16
    fif_max_tris = 1

    num_t_pipes = 2
    noPerspective = 0
    flat = 0
    provokeMode = 0
    vertexSize = 7
    windingOrder = 1 #clockwise
    originLocation = 1 #bottom left
    faceCullerEnable = 1
    mode = "00"
    resx = 20
    resy = 20
    

    i_array_ptr = 0
    v_array_ptr = 4
    f_array_ptr = 32
    poly_storage_structure = 1 

    f1 = open("scripts/generate_top_test_components/file1.txt", "r")
    file1 = f1.read()
    f1.close()
    f2 = open("scripts/generate_top_test_components/file2.txt", "r")
    file2 = f2.read()
    f2.close()

    top_test_code = f"""
    module top_test_gen #(
        parameter DATA_WIDTH = {data_width},
        parameter MAIN_MEM_ADDR_WIDTH = {main_mem_addr_width},
        parameter LOCAL_VERTEX_MEM_ADDR_WIDTH = {local_vertex_mem_addr_width},   
        parameter CYCLES_WAIT_FOR_RECIEVE = 4\'d{cycles_wait_for_recieve},
        parameter MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE = \'d{main_mem_cycles_wait_for_recieve},
        
        parameter FIFO_MAX_FRAGMENTS = {fifo_max_frags}, // must be power of 2
        parameter FIFO_MAX_TRIANGLES = {fif_max_tris}, // must be power of 2

        parameter NUM_T_PIPES = {num_t_pipes},
        
        parameter NOPERSPECTIVE = \'b{noPerspective},
        parameter FLAT = \'b{flat},
        parameter PROVOKEMODE = \'b{provokeMode},
        parameter VERTEXSIZE = 4\'d{vertexSize}, //number of attributes - 1
        parameter WINDINGORDER = 1\'b{windingOrder}, //ACW
        parameter ORIGIN_LOCATION = 1\'b{originLocation}, //TL
        parameter FACE_CULLER_ENABLE = 1\'b{faceCullerEnable},
        parameter MODE = \'b{mode}, //Back
        parameter RESX = 16\'d{resx},
        parameter RESY = 16\'d{resy},
        parameter TOTAL_NUM_TRIS = 32'd{total_num_tris},

        parameter I_ARRAY_PTR = 32\'d{i_array_ptr},
        parameter V_ARRAY_PTR = 32\'d{v_array_ptr},
        parameter F_ARRAY_PTR = 32\'h{f_array_ptr},
        parameter POLY_STORAGE_STRUCTURE = \'b{poly_storage_structure} //anticlockwise by default
    )();
    {file1}{Test_stim}{file2}
    """
    return top_test_code

def float_to_hex(f):
    return hex(struct.unpack('<I', struct.pack('<f', f))[0])

if '__main__' == __name__:
    main()