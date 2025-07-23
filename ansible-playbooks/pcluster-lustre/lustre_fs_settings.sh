#!/bin/bash
#==============================================================================
# lustre_fs_settings.sh - Lustre Filesystem Configuration Settings
#==============================================================================
#
# DESCRIPTION:
#   Provides filesystem-specific configuration settings based on performance
#   and capacity requirements. Settings are selected by filesystem type.
#
# USAGE:
#   source lustre_fs_settings.sh
#   fs_settings <filesystem_type>
#
# FILESYSTEM TYPES:
#   local     - Local NVMe storage configuration
#
# EXAMPLE:
#   source lustre_fs_settings.sh
#   fs_settings small 
#==============================================================================

fs_settings() {
    local fs_type="$1"
    
    case "$fs_type" in
        "small")
            # High performance: 20K IOPS, 4.8TB capacity
            MDT_USE_LOCAL=false
            OST_USE_LOCAL=false
            
            # MGT will be mirrored volumes
            MGT_SIZE=1                         # Size (GB) for MGT volumes
            MGT_VOLUME_TYPE="gp3"              # Volume type for MDT (io1, io2, gp3)
            MGT_THROUGHPUT=125                 # MDT Throughput in MiB/s
            MGT_IOPS=3000                      # MDT IOPS
            
            # Settings for MDTs when *NOT* using local disk (see MDT_USE_LOCAL)
            MDTS_PER_MDS=1                     # Number of MDTs to create per MDS server
            MDT_VOLUME_TYPE="io2"              # Volume type for MDT (io1, io2, gp3)
            MDT_THROUGHPUT=1000                # MDT Throughput in MiB/s
            MDT_SIZE=512                       # Size (GB) for MDT volumes
            MDT_IOPS=12000                     # MDT IOPS
            
            # Settings for OSTs when *NOT* using local disk (see OST_USE_LOCAL)
            OSTS_PER_OSS=1                     # Number of OSTs to create per OSS server
            OST_VOLUME_TYPE="io1"              # Volume type for OST (io1, io2, gp3) 
            OST_THROUGHPUT=250                 # Throughput in MiB/s
            OST_SIZE=1200                      # Size (GB) for OST volumes 
            OST_IOPS=3000                      # IOPS
            ;;
        
        "medium")
            # High performance: 40K IOPS, 48TB capacity
            MDT_USE_LOCAL=false
            OST_USE_LOCAL=false
            
            # MGT will be mirrored volumes
            MGT_SIZE=1                         # Size (GB) for MGT volumes
            MGT_VOLUME_TYPE="gp3"              # Volume type for MDT (io1, io2, gp3)
            MGT_THROUGHPUT=125                 # MDT Throughput in MiB/s
            MGT_IOPS=3000                      # MDT IOPS
            
            # Settings for MDTs when *NOT* using local disk (see MDT_USE_LOCAL)
            MDTS_PER_MDS=1                     # Number of MDTs to create per MDS server
            MDT_VOLUME_TYPE="io2"              # Volume type for MDT (io1, io2, gp3)
            MDT_THROUGHPUT=1000                # MDT Throughput in MiB/s
            MDT_SIZE=512                       # Size (GB) for MDT volumes
            MDT_IOPS=12000                     # MDT IOPS
            
            # Settings for OSTs when *NOT* using local disk (see OST_USE_LOCAL)
            OSTS_PER_OSS=2                     # Number of OSTs to create per OSS server
            OST_VOLUME_TYPE="io1"              # Volume type for OST (io1, io2, gp3) 
            OST_THROUGHPUT=250                 # Throughput in MiB/s
            OST_SIZE=1200                      # Size (GB) for OST volumes 
            OST_IOPS=3000                      # IOPS
            ;;

        "large")
            # High performance: 80K IOPS, 96TB capacity
            MDT_USE_LOCAL=false
            OST_USE_LOCAL=false
            
            # MGT will be mirrored volumes
            MGT_SIZE=1                         # Size (GB) for MGT volumes
            MGT_VOLUME_TYPE="gp3"              # Volume type for MDT (io1, io2, gp3)
            MGT_THROUGHPUT=125                 # MDT Throughput in MiB/s
            MGT_IOPS=3000                      # MDT IOPS
            
            # Settings for MDTs when *NOT* using local disk (see MDT_USE_LOCAL)
            MDTS_PER_MDS=1                     # Number of MDTs to create per MDS server
            MDT_VOLUME_TYPE="io2"              # Volume type for MDT (io1, io2, gp3)
            MDT_THROUGHPUT=1000                # MDT Throughput in MiB/s
            MDT_SIZE=512                       # Size (GB) for MDT volumes
            MDT_IOPS=12000                     # MDT IOPS
            
            # Settings for OSTs when *NOT* using local disk (see OST_USE_LOCAL)
            OSTS_PER_OSS=2                     # Number of OSTs to create per OSS server
            OST_VOLUME_TYPE="io1"              # Volume type for OST (io1, io2, gp3) 
            OST_THROUGHPUT=250                 # Throughput in MiB/s
            OST_SIZE=1200                      # Size (GB) for OST volumes 
            OST_IOPS=3000                      # IOPS
            ;;

        "xlarge")
            # High performance: 160K IOPS, 96TB capacity
            MDT_USE_LOCAL=false
            OST_USE_LOCAL=false
            
            # MGT will be mirrored volumes
            MGT_SIZE=1                         # Size (GB) for MGT volumes
            MGT_VOLUME_TYPE="gp3"              # Volume type for MDT (io1, io2, gp3)
            MGT_THROUGHPUT=125                 # MDT Throughput in MiB/s
            MGT_IOPS=3000                      # MDT IOPS
            
            # Settings for MDTs when *NOT* using local disk (see MDT_USE_LOCAL)
            MDTS_PER_MDS=1                     # Number of MDTs to create per MDS server
            MDT_VOLUME_TYPE="io1"              # Volume type for MDT (io1, io2, gp3)
            MDT_THROUGHPUT=1000                # MDT Throughput in MiB/s
            MDT_SIZE=512                       # Size (GB) for MDT volumes
            MDT_IOPS=12000                     # MDT IOPS
            
            # Settings for OSTs when *NOT* using local disk (see OST_USE_LOCAL)
            OSTS_PER_OSS=2                     # Number of OSTs to create per OSS server
            OST_VOLUME_TYPE="io1"              # Volume type for OST (io1, io2, gp3) 
            OST_THROUGHPUT=250                 # Throughput in MiB/s
            OST_SIZE=1200                      # Size (GB) for OST volumes 
            OST_IOPS=3000                      # IOPS
            ;;
            
        "local")
            # High performance: will depend on Instance Store NVMe volumes 
            MDT_USE_LOCAL=true
            OST_USE_LOCAL=true
            
            # Local file system still use MGT, and it will be on mirrored volumes
            MGT_SIZE=1                         # Size (GB) for MGT volumes
            MGT_VOLUME_TYPE="gp3"              # Volume type for MDT (io1, io2, gp3)
            MGT_THROUGHPUT=125                 # MDT Throughput in MiB/s
            MGT_IOPS=3000                      # MDT IOPS
            
            # No EBS settings, the Instance Store device is fixed 
            MDTS_PER_MDS=1                     # Number of MDTs to create per MDS server

            # No EBS settings, the Instance Store device is fixed 
            OSTS_PER_OSS=1                     # Number of OSTs to create per OSS server
            ;;
            
        *)
            echo "Error: Unknown filesystem type '$fs_type'"
            echo "Available types: small, medium, large, xlarge, local"
            return 1
            ;;
    esac
    
    # Export all variables for use in calling script
    export MDT_USE_LOCAL OST_USE_LOCAL
    export MGT_SIZE MGT_VOLUME_TYPE MGT_THROUGHPUT MGT_IOPS
    export MDTS_PER_MDS MDT_VOLUME_TYPE MDT_THROUGHPUT MDT_SIZE MDT_IOPS
    export OSTS_PER_OSS OST_VOLUME_TYPE OST_THROUGHPUT OST_SIZE OST_IOPS
    
    echo "Filesystem settings loaded for type: $fs_type"
}