
import pandas as pd
from re import I
from telnetlib import WONT
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
import visualise_rendered_pixels as vrp
from Triangles.generate_tris import gen_tris

def main():
    if(len(sys.argv) > 1):
        csv_filepath = sys.argv[1]
        synthesize = sys.argv[2]
        simulate = sys.argv[3]
        # num_tris = int(sys.argv[3])
        # storage_format = sys.argv[4]
        # size = int(sys.argv[5])
        # measure = f"{sys.argv[6]}"
        # wO = sys.argv[7]
        # oL = sys.argv[8]
        # tri_gen_seed_location = int(sys.argv[9])
       
    else:
        pass
        # res
    sim_params_dict = pd.read_csv(csv_filepath, index_col="test_id").loc[0].to_dict()

    res_x = sim_params_dict["res_x"]
    res_y = sim_params_dict["res_y"]
    num_tris = sim_params_dict["num_tris"]
    size = sim_params_dict["size"]
    measure = sim_params_dict["measure"]
    tri_gen_location_seed = sim_params_dict["tri_gen_location_seed"]
    
    fifo_max_frags = sim_params_dict["fifo_max_frags"]
    fifo_max_tris = sim_params_dict["fifo_max_tris"]
    num_t_pipes = sim_params_dict["num_t_pipes"]

    storage_format = sim_params_dict["storage_format"]
    if(storage_format == "individual"):
        poly_storage_structure = 0
    if(storage_format == "strip"):
        poly_storage_structure = 1 #strip
 
    noPerspective = sim_params_dict["noPerspective"] #0 with perspective
    flat = sim_params_dict["flat"] #0 no flat
    provokeMode = sim_params_dict["provokeMode"] #0 # first vertex
    vertexSize = sim_params_dict["vertexSize"] #7 # 8 vertex attributes

    windingOrder = 1
    if(sim_params_dict["windingOrder"] == "CW"):
        windingOrder = 1 #clockwise,
    if(sim_params_dict["windingOrder"] == "ACW"):
        windingOrder = 0 #anticlockwise,
    
    originLocation = 1
    if(sim_params_dict["originLocation"]  == "BL"):
        originLocation = 1 #bottom left
    if(sim_params_dict["originLocation"]  == "TL"):
        originLocation = 0 #top left
    
    faceCullerEnable = sim_params_dict["faceCullerEnable"]
    mode = sim_params_dict["mode"]
    
    vertex_data, index_data = triangle_gen(res_x, res_y, num_tris, storage_format, windingOrder, size, tri_gen_location_seed, sim_params_dict['test_name'])
    # print(index_data,vertex_data)
    # vertex_data, index_data = gen_tris("scripts/Triangles/kitty-cat-kitten-pet-45201.jpeg", num_tris)
    # print(index_data,vertex_data)
    # test_stim_file = open("scripts/generate_top_test_components/three_tri_handwritten_strip.txt", "r")
    # test_stim = test_stim_file.read()
    # test_stim_file.close()
    
    test_stim = generate_verilog(vertex_data, index_data, storage_format)
    
    top_test_gen_code = top_test_gen(
                            test_stim, 
                            num_tris, 
                            fifo_max_frags, fifo_max_tris, num_t_pipes,
                            poly_storage_structure, res_x, res_y,
                            noPerspective, flat,
                            provokeMode, vertexSize,
                            windingOrder, originLocation,
                            faceCullerEnable, mode
                        )

    top_test_file = open("gen/top_test_gen.v", "w")
    top_test_file.write(top_test_gen_code)
    top_test_file.close()

    define_list = f"-D {sim_params_dict['measure']}"
    log_name = f"log_{sim_params_dict['test_name']}"
    if(synthesize == "SYNTH"):
        os.system(f"iverilog -o top_test_gen -c file_list.txt -I src/hardfloat_veri/ {define_list} -s top_test_gen")
        if(simulate == "SIM"):    
            os.system(f"vvp top_test_gen > logs/{log_name}.txt")
            os.system(f"sed -i '1d' logs/{log_name}.txt")
            os.system(f"python3 scripts/visualise_rendered_pixels.py logs/{log_name}.txt {sim_params_dict['test_name']}")
        


def triangle_gen(res_x, res_y, num_tris, storage_format, windingOrder, size, tri_gen_seed_location, test_name):
    x_array = []
    y_array = []
    i_array = []
    z0,z1,z2 = 1,1,1
    seed(tri_gen_seed_location)#

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
            
            if(windingOrder == 1): #clockwise
                x_array += [[x0,y0,z0,1,0,0,345],[x1,y1,z1,0,1,0,345],[x2,y2,z2,0,0,1,345]]
                y_array += [(1,0,0),(0,1,0),(0,0,1)]
                i_array += [3*i,3*i+1,3*i+2]
            if(windingOrder == 0): # anticlockwise
                print("hi")
                x_array += [[x2,y2,z2,0,0,1,345],[x1,y1,z1,0,1,0,345],[x0,y0,z0,1,0,0,345]]
                y_array += [(0,0,1),(0,1,0),(1,0,0)]
                i_array += [3*i,3*i+1,3*i+2]
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
            
        if(windingOrder == 1): #clockwise
            x_array += [[x0,y0,z0,1,0,0,345],[x1,y1,z1,0,1,0,345],[x2,y2,z2,0,0,1,345]]
            y_array += [(1,0,0),(0,1,0),(0,0,1)]
            i_array += [0,1,2]
        if(windingOrder == 0): # anticlockwise
            x_array += [[x2,y2,z2,0,0,1,345],[x1,y1,z1,0,1,0,345],[x0,y0,z0,1,0,0,345]]
            y_array += [(0,0,1),(0,1,0),(1,0,0)]
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

    plt.savefig(f"renders/{test_name}.png")
    plt.show()
    return x_array, i_array
    
def generate_verilog(vertex_data, index_data, storage_format):
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

    ptr_verilog_code = f"i_array_ptr = {i_array_ptr};\nv_array_ptr = {v_array_ptr};\nf_array_ptr = {f_array_ptr};\n#PERIOD;\ntri_mem_wr_en = 1'b1;\n"

    verilog_code = ""
    num_triangles_verilog_code = f"ctrl_reg1[15:0] = TOTAL_NUM_TRIS;\n"
    resolution_verilog_code = f"res_reg[31:16] = RESX;\nres_reg[15:0] = RESY;\n"
    verilog_code = f"{num_triangles_verilog_code}{resolution_verilog_code}{ptr_verilog_code}{index_verilog_code}{vertex_verilog_code}"
    return verilog_code
        # i_array_ptr = I_AR

def top_test_gen(
    Test_stim, total_num_tris = 1, 
    fifo_max_frags = 16, 
    fifo_max_tris = 1,
    num_t_pipes = 2,
    poly_storage_structure = 1,
    resx = 20,
    resy = 20,
    noPerspective = 0,
    flat = 0,
    provokeMode = 0,
    vertexSize = 7,
    windingOrder = 1, #clockwise,
    originLocation = 1,#bottom left
    faceCullerEnable = 1,
    mode = "00"
):

    data_width = 32
    main_mem_addr_width = 32
    local_vertex_mem_addr_width = 3 
    cycles_wait_for_recieve= 1
    main_mem_cycles_wait_for_recieve = 0

    

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
        parameter FIFO_MAX_TRIANGLES = {fifo_max_tris}, // must be power of 2

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

        parameter POLY_STORAGE_STRUCTURE = \'b{poly_storage_structure} //anticlockwise by default
    )();
    {file1}{Test_stim}{file2}
    """
    return top_test_code

def float_to_hex(f):
    return hex(struct.unpack('<I', struct.pack('<f', f))[0])

if '__main__' == __name__:
    main()