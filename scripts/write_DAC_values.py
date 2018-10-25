import os

import argparse

parser = argparse.ArgumentParser(description='Arguments to supply to write_DAC_values.py')

parser.add_argument('OH', type=str, help="OH number", metavar='OH')
parser.add_argument('nominalDacFileList', type=str, help="Name of a file containing a list of register names and NominalDACValues.txt files. Format:register_name1 <space> /path/to/nominal/DAC/file1 <newline> register_name2 <space> /path/to/nominal/DAC/file2 <newline> ... ", metavar='nominalDacFileList')
parser.add_argument('--dry_run', dest='dry_run', action='store_true', help="If this flag is set the script will not overwrite the vfat3 config files.")

args = parser.parse_args()

#values copied from https://github.com/cms-gem-daq-project/cmsgemos/blob/generic-amc-RPC-v3-short-term/gempython/tools/amc_user_functions_xhal.py#L14-L43
max_DAC_values = {
            "BIAS_PRE_I_BIT": 0xff,
            "BIAS_PRE_I_BLCC": 0x3f,
            "BIAS_SH_I_BFCAS": 0xff,
            "BIAS_SH_I_BDIFF": 0xff,
            "BIAS_SD_I_BDIFF": 0xff,
            "BIAS_SD_I_BFCAS": 0xff,
            "BIAS_SD_I_BSF": 0x3f,
            "BIAS_CFD_DAC_1": 0x3f,
            "BIAS_CFD_DAC_2": 0x3f,
            "HYST": 0x3f,
            "THR_ARM_DAC": 0xff,
            "THR_ZCC_DAC": 0xff,
            "BIAS_PRE_VREF": 0xff,
            "THR_ARM_DAC": 0xff,
            "THR_ZCC_DAC": 0xff,
            "ADC_VREF": 0x3
            }

nominal_DAC_value_files = {}

for line in open(args.nominalDacFileList):
    if line[0] == "#":
        continue
    line = line.strip(' ').strip('\n')
    first = line.split(' ')[0].strip(' ')
    second = line.split(' ')[1].strip(' ')

    if first not in max_DAC_values.keys():
        print('Warning: no maximum value found for register: '+first)
    
    nominal_DAC_value_files[first] = second

for reg in nominal_DAC_value_files.keys():
    print "setting the register "+str(reg)+ " using the file:"+nominal_DAC_value_files[reg]
    fname=nominal_DAC_value_files[reg]
    f = open(nominal_DAC_value_files[reg])
    for line in f:
        vfat=int(line.split('\t')[0])
        value=int(line.split('\t')[1])

        if value < 0:
            value = 0

        if vfat not in [11,12]:     
            if reg in max_DAC_values.keys() and value > max_DAC_values[reg]:
                print str(vfat) +": "+ str(value) +" --> " + str(max_DAC_values[reg])
                value = max_DAC_values[reg]
            else:
                print str(vfat)+ ": "+str(value)
            
            if args.dry_run:
                os.system("sed '/^"+reg+"/{s/ [0-9]\+/ "+str(value)+"/;}' /mnt/persistent/gemdaq/vfat3/config_OH"+str(args.OH)+"_VFAT"+str(vfat)+"_cal.txt")
            else:  
                os.system("sed -i '/^"+reg+"/{s/ [0-9]\+/ "+str(value)+"/;}' /mnt/persistent/gemdaq/vfat3/config_OH"+str(args.OH)+"_VFAT"+str(vfat)+"_cal.txt")  
