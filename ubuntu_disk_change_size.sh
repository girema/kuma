#This is not a true bach script, you can use these commands as a guidance for chaning Ubuntu machine's disk partition

#preparation step - create a partition:
fdisk -l
gdisk /dev/sda

#p (to view the current partition layout)
#n (new partition)
#Enter (to let it automatically choose the partition number. Take note of this number)
#Enter (to let it automatically choose the first sector)
#Enter (to let it automatically choose the last sector)
#8E00 (the type code for the 'Linux LVM’)
#p (to see the new partition. Verify that it has the correct size.)
#w (to write the changes to the disk)
#Y (to confirm)

#Basic steps:
sudo pvdisplay /dev/sda3 
sudo pvresize /dev/sda3
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv

#validation
df -h
