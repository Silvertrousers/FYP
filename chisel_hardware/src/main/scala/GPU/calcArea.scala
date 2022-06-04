// See LICENSE.txt for license details.
package gpu

import chisel3._
import chisel3.util._
import hardfloat.{AddRecFN, MulRecFN}
//somehow import the chiselFloat package

class calcArea(expWidth: Int, sigWidth: Int) extends Module {
        val io = IO(new Bundle {
        val P1  = Input(UInt(((expWidth + sigWidth + 1)*2).W)) //x,y
        val P2  = Input(UInt(((expWidth + sigWidth + 1)*2).W)) //x,y
        val P3  = Input(UInt(((expWidth + sigWidth + 1)*2).W)) //x,y
        val A   = Output(UInt((expWidth + sigWidth + 1).W))
    })

    val x1 = io.P1(63,32)
    val y1 = io.P1(31,0)
    val x2 = io.P2(63,32)
    val y2 = io.P2(31,0)
    val x3 = io.P3(63,32)
    val y3 = io.P3(31,0)

    val FPADD1 = Module(new AddRecFN(8,23))
    FPADD1.io.a := y2
    FPADD1.io.b := y3 //need to negate y3
    
    val FPADD2 = Module(new AddRecFN(8,23))
    FPADD2.io.a := y3
    FPADD2.io.b := y1 //need to negate y1

    val FPADD3 = Module(new AddRecFN(8,23))
    FPADD3.io.a := y1
    FPADD3.io.b := y2 //need to negate y2

    val FPMUL1 = Module(new MulRecFN(8,23))
    FPMUL1.io.a := FPADD1.io.out
    FPMUL1.io.b := x1 

    val FPMUL2 = Module(new MulRecFN(8,23))
    FPMUL2.io.a := FPADD2.io.out
    FPMUL2.io.b := x2

    val FPMUL3 = Module(new MulRecFN(8,23))
    FPMUL3.io.a := FPADD3.io.out
    FPMUL3.io.b := x3
    
    val FPADD4 = Module(new AddRecFN(8,23))
    FPADD4.io.a := FPMUL2.io.out
    FPADD4.io.b := FPMUL3.io.out

    val FPADD5 = Module(new AddRecFN(8,23))
    FPADD5.io.a := FPMUL1.io.out
    FPADD5.io.b := FPADD4.io.out

    io.A := FPADD5.io.out // need to multiply by 0.5


}