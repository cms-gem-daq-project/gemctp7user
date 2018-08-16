#!/bin/env python

if __name__ == '__main__': 
    import os
    
    from optparse import OptionParser
    
    parser = OptionParser()
    parser.add_option("-g", "--gtx", type="int", dest="gtx",
            help="GTX on the AMC", metavar="gtx", default=0)
    
    (options, args) = parser.parse_args()
    
    for vfat in range(0,24):
        os.system('cp /mnt/persistent/gemdaq/vfat3/conf.txt /mnt/persistent/gemdaq/vfat3/config_OH%i_VFAT%i_cal.txt'%(options.gtx,vfat))
        os.system('ln -sf /mnt/persistent/gemdaq/vfat3/config_OH%i_VFAT%i_cal.txt /mnt/persistent/gemdaq/vfat3/config_OH%i_VFAT%i.txt'%(options.gtx,vfat,options.gtx,vfat))
