
# import os

# class paramaters:
#     def __init__(self, name, age):
#         self.name = name
#         self.age = age



# #decide on triangle coords
# #decide on point to inbterpolate
# QuarterFP = "32'h3e800000"

# PIN = f"{QuarterFP},{QuarterFP}"
# PIN = "{"+PIN+"}"
# NOPERSPECTIVE = "'b0"
# FLAT = "'b0"
# PROVOKEMODE = "'b0"
# VERTEXSIZE = "4'd15"

# testName = "withPersp"

# TestModuleInst = f"""
# fragment_interpolator_Test#(
#     {PIN},
#     {NOPERSPECTIVE},
#     {FLAT},
#     {PROVOKEMODE},
#     {VERTEXSIZE}
# ) Test_{testName} ();

# """

# PIN = f"{QuarterFP},{QuarterFP}"
# PIN = "{"+PIN+"}"
# NOPERSPECTIVE = "'b1"
# FLAT = "'b0"
# PROVOKEMODE = "'b0"
# VERTEXSIZE = "4'd15"

# testName = "noPersp"

# TestModuleInst = f"""
# {TestModuleInst}

# fragment_interpolator_Test#(
#     {PIN},
#     {NOPERSPECTIVE},
#     {FLAT},
#     {PROVOKEMODE},
#     {VERTEXSIZE}
# ) Test_{testName} ();

# """

# PIN = f"{QuarterFP},{QuarterFP}"
# PIN = "{"+PIN+"}"
# NOPERSPECTIVE = "'b0"
# FLAT = "'b1"
# PROVOKEMODE = "'b0"
# VERTEXSIZE = "4'd15"

# testName = "flat_provokeA"

# TestModuleInst = f"""
# {TestModuleInst}

# fragment_interpolator_Test#(
#     {PIN},
#     {NOPERSPECTIVE},
#     {FLAT},
#     {PROVOKEMODE},
#     {VERTEXSIZE}
# ) Test_{testName} ();

# """

# TbModule = f"""
# module fragment_interpolator_tb();
# {TestModuleInst}
# endmodule
# """
# #generate memory contents
# #instantiate test module

# os.system(f"echo \"{TbModule}\" > fragment_interpolator_tb.v")

# #Run Test
# #test_cmd = "iverilog -o fragment_interpolator_tb -c file_list.txt -I src/hardfloat_veri/ -v -s fragment_interpolator_tb; vvp fragment_interpolator_tb"

# #os.system(test_cmd)

x1,y1 = (0,0)
x2,y2 = (0,1)
x3,y3 = (1,0)



print(0.5*((x1*(y2-y3)) +(x2*(y3-y1)) +(x3*(y1-y2))))

x1,y1 = (-1,0)
x2,y2 = (-1,-1)
x3,y3 = (0,-1)

print(0.5*((x1*(y2-y3)) +(x2*(y3-y1)) +(x3*(y1-y2))))