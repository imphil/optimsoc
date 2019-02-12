import logging

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.generators.bit import wave, intermittent_single_cycles, random_50_percent
from cocotb.regression import TestFactory

from lisnoc.drivers import LisNoCMaster, random_class

@cocotb.coroutine
def clock_gen(signal):
    while True:
        signal <= 0
        yield Timer(5)
        signal <= 1
        yield Timer(5)

class NoCDemuxTB(object):
    def __init__(self, dut):
        self.dut = dut
        self.port_in = LisNoCMaster(dut, "in", dut.clk)

        self.dut.out0_ready <= 1
        self.dut.out1_ready <= 1
        self.dut.out2_ready <= 1

    @cocotb.coroutine
    def reset(self, duration=20):
        self.dut._log.debug("Resetting DUT")
        self.dut.rst <= 1
        yield Timer(duration)
        yield RisingEdge(self.dut.clk)
        self.dut.rst <= 0
        self.dut._log.debug("Out of reset")

@cocotb.coroutine
def run_test(dut, waitstate_inserter = None, class_generator = None):
    """
    Try accessing the design
    """
    cocotb.fork(clock_gen(dut.clk))
    yield RisingEdge(dut.clk)
    tb = NoCDemuxTB(dut)

    yield tb.reset()

    if waitstate_inserter is not None:
        tb.port_in.set_valid_generator(waitstate_inserter())

    if class_generator is not None:
        tb.port_in.set_class_generator(class_generator(3))
        
    s = cocotb.fork(tb.port_in.send(range(1,10)))

    yield [s.join()]
    
    yield(Timer(200))

factory = TestFactory(run_test)
factory.add_option("waitstate_inserter",
                   [None, wave, intermittent_single_cycles, random_50_percent])
factory.add_option("class_generator",
                   [None, random_class])
factory.generate_tests()
