import logging

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.generators.bit import wave, intermittent_single_cycles, random_50_percent
from cocotb.regression import TestFactory

from lisnoc.drivers import LisNoCMaster, random_length

@cocotb.coroutine
def clock_gen(signal):
    while True:
        signal <= 0
        yield Timer(5)
        signal <= 1
        yield Timer(5)

class NoCMuxTB(object):
    def __init__(self, dut):
        self.dut = dut
        self.in0 = LisNoCMaster(dut, "in0", dut.clk)
        self.in1 = LisNoCMaster(dut, "in1", dut.clk)
        self.in2 = LisNoCMaster(dut, "in2", dut.clk)

        self.dut.out_ready <= 1

    @cocotb.coroutine
    def reset(self, duration=20):
        self.dut._log.debug("Resetting DUT")
        self.dut.rst <= 1
        yield Timer(duration)
        yield RisingEdge(self.dut.clk)
        self.dut.rst <= 0
        self.dut._log.debug("Out of reset")

@cocotb.coroutine
def run_test(dut, length_generator = None, waitstate_inserter = None):
    """
    Try accessing the design
    """
    cocotb.fork(clock_gen(dut.clk))
    yield RisingEdge(dut.clk)
    tb = NoCMuxTB(dut)

    yield tb.reset()

    if waitstate_inserter is not None:
        tb.in0.set_valid_generator(waitstate_inserter())
        tb.in1.set_valid_generator(waitstate_inserter())
        tb.in2.set_valid_generator(waitstate_inserter())

    tb.in0.set_packet_generator(packet_generator(length_generator))
        
    s0 = cocotb.fork(tb.in0.send(range(1,10)))
    s1 = cocotb.fork(tb.in1.send(range(1,10)))
    s2 = cocotb.fork(tb.in2.send(range(1,10)))
    
    yield [s0.join(), s1.join(), s2.join()]
    
    yield(Timer(200))

factory = TestFactory(run_test)
factory.add_option("waitstate_inserter",
                   [None, wave, intermittent_single_cycles, random_50_percent])
factory.add_option("length_generator",
                   [None, random_length])
factory.generate_tests()
