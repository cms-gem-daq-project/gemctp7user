__author__ = 'evka'

import xml.etree.ElementTree as xml
import textwrap as tw

ADDRESS_TABLE_TOP = '../doc/address_table/gem_amc_top.xml'
TOP_NODE_NAME = 'GEM_AMC'

class Register:
    parent = None
    name = ''
    address = 0x0
    description = ''
    permission = ''
    mask = 0x0

    def __init__(self, xmlNode, parent):
        self.children = []
        self.parent = parent
        name = xmlNode.get('id')


        if xmlNode.get('id') is not None:


    def addReg(self, reg):
        self.children.append(reg)

    def isValidReg(self):
        return self.name is not None and self.address is not None and self.permission is not None and self.mask is not None

    def getName(self):
        return self.parent.getName() + '.' + self.name if self.parent != None else self.name;

    def getAddress(self):
        return self.parent.address + self.address if self.parent != None else self.address;

def main():
    print("Hi, I'm your CTP7 manager! :)")

def findRegisters(node, parent):
    if node.get('address') is not None:
        address = baseAddress + parseInt(node.get('address'))

    if node.get('address') is not None and node.get('permission') is not None and node.get('mask') is not None:
        reg = Register()
        reg.name = name
        reg.address = address
        reg.description = node.get('description')
        reg.permission = node.get('permission')
        reg.mask = parseInt(node.get('mask'))
        msb, lsb = getLowHighFromBitmask(reg.mask)
        reg.msb = msb
        reg.lsb = lsb
        reg.signal = node.get('fw_signal')
        reg.default = parseInt(node.get('fw_default'))
        if node.get('fw_is_write_pulse') is not None:
            reg.isWritePulse = bool(node.get('fw_is_write_pulse') == 'true')
        if node.get('fw_write_pulse_length') is not None:
            reg.writePulseLength = parseInt(node.get('fw_write_pulse_length'))
        if node.get('fw_read_pulse_signal') is not None:
            reg.readPulseSignal = node.get('fw_read_pulse_signal')
        if node.get('fw_read_pulse_length') is not None:
            reg.readPulseLength = parseInt(node.get('fw_read_pulse_length'))

        if module is None:
            error = 'Module is not set, cannot add register ' + reg.name
            raise ValueError(error)
        if not reg.isValidReg():
            raise ValueError('One or more attributes for register %s are missing.. %s' % (reg.name, reg.toString()))

        module.addReg(reg)

    for child in node:
        findRegisters(child, name, address, modules, module)

if __name__ == '__main__':
    main()