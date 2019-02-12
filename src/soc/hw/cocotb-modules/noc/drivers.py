
import cocotb
from cocotb.drivers import ValidatedBusDriver
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.binary import BinaryValue

import random
from cocotb.decorators import public

@public
def random_class(max=8):
    while True:
        yield random.randint(0,max)

@public
def random_length(max=16):
    while True:
        yield random.randint(1,max)
        
@public
def packet_generator(num=100,
                     length_generator=None,
                     class_generator=None):
    while True:
        if length_generator is None:
            l = 8
        else:
            l = length_generator()
        if class_generator is None:
            c = 0
        else:
            c = class_generator()
        
class LisNoCMaster(ValidatedBusDriver):
    _signals = ["flit", "valid", "ready"]

    def __init__(self, entity, name, clock, validgen=None):
        ValidatedBusDriver.__init__(self, entity, name, clock, validgen)
        self.set_valid_generator(valid_generator=validgen)
        self.bus.valid <= 0

    def set_class_generator(self, class_gen):
        self.class_generator(class_gen)
        
    @cocotb.coroutine
    def _wait_ready(self):
        """Wait for a ready cycle on the bus before continuing
            Can no longer drive values this cycle...
        """
        while not self.bus.ready == 1:
            yield FallingEdge(self.clock)
        yield RisingEdge(self.clock)
        
    @cocotb.coroutine
    def _send_flit(self, flit, first = False, last = False, sync=True):
        if not self.on:
            for i in range(self.off):
                yield RisingEdge(self.clock)
            self._next_valids()

        if self.on is not True and self.on:
            self.on -= 1

        self.bus.valid <= 1
        f = BinaryValue()
        f.binstr = "1" if first else "0"
        f.binstr += "1" if last else "0"
        f.binstr += "{0:032b}".format(flit)
        self.bus.flit <= f
        yield self._wait_ready()
        self.bus.valid <= 0
        
    @cocotb.coroutine
    def send(self, pkt, sync=True):
        if sync:
            yield RisingEdge(self.clock)

        yield self._send_flit(pkt[0], True, (len(pkt) == 1))

        if len(pkt) == 1:
            return
        
        for f in pkt[1:-1]:
            yield self._send_flit(f)

        yield self._send_flit(pkt[-1], False, True)
