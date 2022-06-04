// // See LICENSE.txt for license details.
// package gpu

// import chisel3._
// import chisel3.util._
// import hardfloat.{DivSqrtRecFNToRaw_small}
// //somehow import the chiselFloat package

// class CalcBaryCoords(expWidth: Int, sigWidth: Int) extends Module {
//         val io = IO(new Bundle {
//         val Pa  = Input(UInt(((expWidth + sigWidth + 1)*2).W)) //x,y
//         val Pb  = Input(UInt(((expWidth + sigWidth + 1)*2).W)) //x,y
//         val Pc  = Input(UInt(((expWidth + sigWidth + 1)*2).W))   //x,y
//         val P   = Input(UInt(((expWidth + sigWidth + 1)*2).W))   //x,y
//         val A   = Output(UInt((expWidth + sigWidth + 1).W))
//         val B   = Output(UInt((expWidth + sigWidth + 1).W))
//         val C   = Output(UInt((expWidth + sigWidth + 1).W))
//     })

//     val CalcArea1 = Module(new CalcArea(expWidth, sigWidth))
//     CalcArea1.io.P1 := io.P
//     CalcArea1.io.P2 := io.P2
//     CalcArea1.io.P3 := io.P3

//     val CalcArea2 = Module(new CalcArea(expWidth, sigWidth))
//     CalcArea1.io.P1 := io.P1
//     CalcArea1.io.P2 := io.P
//     CalcArea1.io.P3 := io.P3

//     val CalcArea3 = Module(new CalcArea(expWidth, sigWidth))
//     CalcArea1.io.P1 := io.P1
//     CalcArea1.io.P2 := io.P2
//     CalcArea1.io.P3 := io.P

//     val CalcArea4 = Module(new CalcArea(expWidth, sigWidth))
//     CalcArea1.io.P1 := io.P1
//     CalcArea1.io.P2 := io.P2
//     CalcArea1.io.P3 := io.P3

//     val Div1_14  = Module(new DivSqrtRecFN_small(expWidth, sigWidth, options: Int))
//     Div1_14.io.a := CalcArea1.io.A
//     Div1_14.io.b := CalcArea4.io.A
//     Div1_14.io.sqrtOp := 0
//     val Sqrt1 = Module(new DivSqrtRecFN_small(expWidth, sigWidth, options: Int))
//     Sqrt1.io.a := Div1_14.io.out
//     Sqrt1.io.sqrtOp := 1
    
//         // /*--------------------------------------------------------------------
//         // *--------------------------------------------------------------------*/
//         // val inReady        = Output(Bool())
//         // val inValid        = Input(Bool())
//         // val sqrtOp         = Input(Bool())
//         // val a              = Input(UInt((expWidth + sigWidth + 1).W))
//         // val b              = Input(UInt((expWidth + sigWidth + 1).W))
//         // val roundingMode   = Input(UInt(3.W))
//         // val detectTininess = Input(UInt(1.W))
//         // /*--------------------------------------------------------------------
//         // *--------------------------------------------------------------------*/
//         // val outValid_div   = Output(Bool())
//         // val outValid_sqrt  = Output(Bool())
//         // val out            = Output(UInt((expWidth + sigWidth + 1).W))
//         // val exceptionFlags = Output(UInt(5.W))
//     val Div2_24  = Module(new DivSqrtRecFN_small(expWidth, sigWidth, options: Int))
//     val Sqrt2 = Module(new DivSqrtRecFN_small(expWidth, sigWidth, options: Int))
//     val Div3_34  = Module(new DivSqrtRecFN_small(expWidth, sigWidth, options: Int))
//     val Sqrt3 = Module(new DivSqrtRecFN_small(expWidth, sigWidth, options: Int))

//     io.A := 
//     io.B := 
//     io.C :=

// }