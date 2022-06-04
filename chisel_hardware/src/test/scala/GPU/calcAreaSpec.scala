package gpu

import chisel3._
import chisel3.util._
import chisel3.iotesters._
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class CalcAreaTest(dut: calcArea) extends PeekPokeTester(dut) {
    val inputs = List( ((0.U(32.W), 0.U(32.W)), (0.U(32.W),"h3f800000".U), ("h3f800000".U,0.U(32.W))), (("h3f800000".U, "h3f800000".U), (0.U(32.W),"h3f800000".U), ("h3f800000".U,0.U(32.W))))
    val outputs = List(0x3f000000, 0x3f000000)

    // val P1  = Bits(INPUT, 64) //x,y
    // val P2  = Bits(INPUT, 64) //x,y
    // val P3  = Bits(INPUT, 64)   //x,y
    // val A   = Bits(OUTPUT, 32)

    var i = 0
    do {
        poke(dut.io.P1, Cat(inputs(i)._1._1, inputs(i)._1._2))
        poke(dut.io.P2, Cat(inputs(i)._2._1, inputs(i)._2._2))
        poke(dut.io.P3, Cat(inputs(i)._3._1, inputs(i)._3._2))

        expect(dut.io.A, outputs(i))
        step(1)

        
        i += 1
    } while (t < 100 && i < 2)

    if (t >= 100) fail
}

class CalcAreaSpec extends AnyFlatSpec with Matchers {
    behavior of "calcAreaSpec"

    it should "compute area excellently" in {
    chisel3.iotesters.Driver(() => new calcArea(8,23)) { dut =>
        new CalcAreaTest(dut)
    } should be(true)
    }
}