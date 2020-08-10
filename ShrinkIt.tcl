
# https://nulib.com/library/FTN.e08002.htm

little_endian
requires 0 "4E F5 46 E9 6C E5"

# kind,class to name mapping
set TNAMES {
	"ASCII Text"
	"Directory"
	"Data Fork"
	"Filename"
	"Buffer"
	"Undefined"
	"Disk Image"
	"Undefined"
	"Icon"
	"Undefined"
	"Resource Fork"
	"Undefined"
}

set COMPRESSION {
	"Uncompressed"
	"Huffman"
	"Dynamic LZW/1"
	"Dynamic LZW/2"
	"12-bit Compress"
	"16-bit Compress"
}


proc date_time {name} {

	section $name {
		set s [uint8 "Second"]
		set m [uint8 "Minute"]
		set h [uint8 "Hour"]
		set yy [uint8 "Year"]
		set dd [uint8 "Day"]
		set mm [uint8 "Month"]
		uint8 
		uint8 "Weekday"

		sectionvalue [format "%04d-%02d-%02d %d:%02d:%02d" [expr 1900+$yy] [expr $mm+1] [expr $dd+1] $h $m $s ]
	}
}

proc one_file {} {

	global TNAMES
	global COMPRESSION

	# 1 or more header blocks
	# with 1 or more threads
	section "Header Block" {
		set header_start [pos] ;# current position.

		hex 4 "NuFX ID"
		uint16 -hex "CRC"
		set attr_count [uint16 "Attr Count"]
		set version [uint16 "Version"]
		set total_threads [uint32 "Total Threads"]
		uint16 "File System"
		uint16 "File Sys Info"
		uint32 -hex "Access"
		uint32 -hex "File Type"
		uint32 -hex "Aux Type"
		uint16 -hex "Storage Type" ;# block size for disk images
		# bytes 8 "Create Date"
		# bytes 8 "Mod Date"
		# bytes 8 "Archive Date"
		date_time "Create Date"
		date_time "Mod Date"
		date_time "Archive Date"
		if { $version > 0 } {
			set os [uint16 "Option Size"]
			if { $os != 0} {
				bytes [expr $os - 2] "Option List"
				if { $os & 1} { move 1 } ;# padding byte
			}
		}
		# set attr_start [pos] ;# current position.

		# attributes
		# bytes $attr_count "Attributes"
		goto [expr $header_start + $attr_count - 2]
		set flen [uint16]
		if { $flen > 0 } {
			ascii $flen "Filename"
		}
	}

	set types {}
	set sizes {}
	section "Threads" {
		for { set i 0 } {$i < $total_threads } {incr i} {

			section "Thread" {
				set class [uint16 "Class"]
				uint16 "Format"
				set kind [uint16 "Kind"]
				uint16 -hex "CRC"
				uint32 "EOF"
				set ceof [uint32 "Compressed EOF"]

				if { $class < 4 && $kind < 3 } {
					set ix [expr $kind * 4 + $class ]
					lappend types [lindex $TNAMES $ix]
					sectionvalue [lindex $TNAMES $ix]
				} else {
					lappend types "Undefined"
				}
				lappend sizes $ceof
			}
		}
	}

	# data for the threads....
	section "Data" {

		for { set i 0 } {$i < $total_threads } {incr i} {

			section [lindex $types $i] {

				bytes [lindex $sizes $i] "Data"
			}
		}
	}


}


section "Master Header" {

	hex 6 "NuFile ID"
	uint16 -hex "CRC"
	set total_records [uint32 "Total Records"]
	date_time "Archive Create"
	date_time "Archive Mod"
	uint16 "Master Version"
	bytes 8 "Reserved"
	uint32 "Master EOF"

	# bytes 6 "Reserved"
	move 6
}

for { set i 0 } {$i < $total_records } {incr i} {
	one_file
}
