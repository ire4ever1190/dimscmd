import commandOptions
import dimscord
import unittest
import options
import macroUtils

#
# This test file is basically useless
# There was more stuff to test except I cleaned up a lot and was test with just this
#

test "Getting basic parameter":
    check getCommandOption("int") == acotInt

