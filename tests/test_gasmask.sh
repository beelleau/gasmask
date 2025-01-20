#!/usr/bin/env bash
#
# gasmask unit tests with shunit2
# requires: shunit2, bash 3.2+, cat, grep

# shellcheck disable=1091

source "gasmask"

assert_grep() {
  # checks for the presence of a substring
  #
  # ARG $1: substring you are expecting
  # ARG $2: actual results

  echo "$2" | grep -q "$1" || fail "Expected to find '$1' in:\n$2"
}

test_show_noarg() {
  local result="" expect=""
  result="$(show_noarg)"
  expect="$(cat << EOF

gasmask is a Bash-written copy of Whatmask

whatmask: Copyright (C) 2001-2003 Joe Laffey <joe@laffeycomputer.com>
Visit http://www.laffeycomputer.com/whatmask.html for more information
gasmask: Copyright (C) 2024-2025 Kyle Belleau <kylejbelleau@gmail.com>
Visit https://github.com/beelleau/gasmask for more information

This program is licensed under the GNU General Public License version 3
or later (GPL-3.0-or-later).

gasmask may be used two ways:

Given a mask:          gasmask <CIDR bits>
               - or -  gasmask <subnet mask>
               - or -  gasmask <hex subnet mask>
               - or -  gasmask <wildcard bit mask>
 NOTE: gasmask will autodetect the input and show you all four.


Given an ip/mask:      gasmask <IP address>/<netmask>
       <netmask> may be one of the following:
                       CIDR notation (e.g. "24")
                       Netmask notation (e.g. "255.255.255.0")
                       Hex Netmask notation (e.g. "0xffffff00")
                       Wildcard bit notation (e.g. "0.0.0.255")
 NOTE: gasmask will autodetect the netmask format.

EOF
        )"

  assertEquals "$expect" "$result"
}

test_subnet_which_initial() {
  local result="" expect="subnetmask"
  result="$(subnet_which_initial 255.255.255.0)"
  assertEquals "$expect" "$result"

  local result="" expect="cidr"
  result="$(subnet_which_initial 24)"
  assertEquals "$expect" "$result"

  local result="" expect="hex"
  result="$(subnet_which_initial 0xffffc000)"
  assertEquals "$expect" "$result"

  local result="" expect="wildcard"
  result="$(subnet_which_initial 0.127.255.25)"
  assertEquals "$expect" "$result"

  local result="" expect="cidr"
  result="$(subnet_which_initial 34)"
  assertEquals "$expect" "$result"

  local result="" expect="subnetmask"
  result="$(subnet_which_initial 192.168.23.2)"
  assertEquals "$expect" "$result"

  local result="" expect="cidr"
  result="$(subnet_which_initial yyy)"
  assertEquals "$expect" "$result"
}

test_validate_cidr() {
  local result=""
  result="$(validate_cidr 24)"
  assertEquals "0" $?

  local result=""
  result="$(validate_cidr 34 2>&1)"
  assertEquals "1" $?
  assert_grep "CIDR notations must be a number between 0 and 32 inclusive!" \
              "$result"

  local result=""
  result="$(validate_cidr 014 2>&1)"
  assertEquals "1" $?
  assert_Grep "CIDR notations must be a number between 0 and 32 inclusive!" \
              "$result"

  local result=""
  result="$(validate_cidr 0)"
  assertEquals "0" $?

  local result=""
  result="$(validate_cidr 1)"
  assertEquals "0" $?
}

test_validate_subnet() {
  local result=""
  result="$(validate_subnet 255.255.255.0)"
  assertEquals "0" $?

  local result=""
  result="$(validate_subnet 255.255.255.00 2>&1)"
  assertEquals "1" $?
  assert_grep "is not a valid subnet mask or wildcard bit mask!" "$result"

  local result=""
  result="$(validate_subnet 255.255.255.255)"
  assertEquals "0" $?

  local result=""
  result="$(validate_subnet 128.0.0.0)"
  assertEquals "0" $?
}

test_validate_hex() {
  local result=""
  result="$(validate_hex 0xffffff00)"
  assertEquals "0" $?

  local result=""
  result="$(validate_hex 0xffffffcds 2>&1)"
  assertEquals "1" $?
  assert_grep "is not a valid subnet mask!" "$result"
  assert_grep "Hex values need 8 chars" "$result"

  local result=""
  result="$(validate_hex 0xff000000)"
  assertEquals "0" $?

  local result=""
  result="$(validate_hex 0xfffffff8)"
  assertEquals "0" $?
}

test_validate_wildcard() {
  local result=""
  result="$(validate_wildcard 0.0.0.0)"
  assertEquals "0" $?

  local result=""
  result="$(validate_wildcard 0.0.0.128 2>&1)"
  assertEquals "1" $?
  assert_grep "is not a valid subnet mask or wildcard bit mask!" "$result"

  local result=""
  result="$(validate_wildcard 0.0.0.127)"
  assertEquals "0" $?

  local result=""
  result="$(validate_wildcard 31.255.255.255)"
  assertEquals "0" $?
}

test_validate_ip_address() {
  local result=""
  result="$(validate_ip_address 192.168.27.2)"
  assertEquals "0" $?

  local result=""
  result="$(validate_ip_address 1920.15.2.4 2>&1)"
  assertEquals "1" $?
  assert_grep "is not a valid IP address!" "$result"
  assert_grep "IP addresses take the form" "$result"

  local result=""
  result="$(validate_ip_address 10.11.12.13)"
  assertEquals "0" $?

  local result=""
  result="$(validate_ip_address 1.0.0.0)"
  assertEquals "0" $?

  local result=""
  result="$(validate_ip_address 0 2>&1)"
  assertEquals "1" $?
  assert_grep "is not a valid IP address!" "$result"
  assert_grep "IP addresses take the form" "$result"

  local result=""
  result="$(validate_ip_address 234.55.0000000.3 2>&1)"
  assertEquals "1" $?
  assert_grep "is not a valid IP address!" "$result"
  assert_grep "IP addresses take the form" "$result"
}

test_cidr_to_subnetmask() {
  local result="" expect="255.255.255.0"
  result="$(cidr_to_subnetmask 24)"

  assertEquals "$expect" "$result"

  local result="" expect="255.248.0.0"
  result="$(cidr_to_subnetmask 13)"
  assertEquals "$expect" "$expect"
}

test_hex_to_subnetmask() {
  local result="" expect="255.255.254.0"
  result="$(hex_to_subnetmask 0xfffffe00)"
  assertEquals "$expect" "$result"

  local result="" expect="254.0.0.0"
  result="$(hex_to_subnetmask 0xfe000000)"
  assertEquals "$expect" "$result"
}

test_wildcard_to_subnetmask() {
  local result="" expect="255.255.255.224"
  result="$(wildcard_to_subnetmask 0.0.0.31)"
  assertEquals "$expect" "$result"

  local result="" expect="240.0.0.0"
  result="$(wildcard_to_subnetmask 15.255.255.255)"
  assertEquals "$expect" "$result"
}

test_subnetmask_to_cidr() {
  local result="" expect="10"
  result="$(subnetmask_to_cidr 255.192.0.0)"
  assertEquals "$expect" "$result"

  local result="" expect="29"
  result="$(subnetmask_to_cidr 255.255.255.248)"
  assertEquals "$expect" "$result"
}

test_subnetmask_to_hex() {
  local result="" expect="0xffff0000"
  result="$(subnetmask_to_hex 255.255.0.0)"
  assertEquals "$expect" "$result"

  local result="" expect="0xffffffe0"
  result="$(subnetmask_to_hex 255.255.255.224)"
  assertEquals "$expect" "$result"
}

test_subnetmask_to_wildcard() {
  local result="" expect="0.0.255.255"
  result="$(subnetmask_to_wildcard 255.255.0.0)"
  assertEquals "$expect" "$result"

  local result="" expect="0.0.7.255"
  result="$(subnetmask_to_wildcard 255.255.248.0)"
  assertEquals "$expect" "$result"
}

test_cidr_to_no_ips() {
  local result="" expect="1073741822"
  result="$(cidr_to_no_ips 2)"
  assertEquals "$expect" "$result"

  local result="" expect="1048574"
  result="$(cidr_to_no_ips 12)"
  assertEquals "$expect" "$result"

  local result="" expect="2046"
  result="$(cidr_to_no_ips 21)"
  assertEquals "$expect" "$result"

  local result="" expect="6"
  result="$(cidr_to_no_ips 29)"
  assertEquals "$expect" "$result"
}

test_get_ip_network_address() {
  local result="" expect="192.168.25.0"
  result="$(get_ip_network_address 192.168.25.2 255.255.255.0)"
  assertEquals "$expect" "$result"

  local result="" expect="10.10.4.96"
  result="$(get_ip_network_address 10.10.4.96 255.255.255.240)"
  assertEquals "$expect" "$result"

  local result="" expect="172.20.204.0"
  result="$(get_ip_network_address 172.20.206.23 255.255.252.0)"
  assertEquals "$expect" "$result"
}

test_get_ip_broadcast_address() {
  local result="" expect="192.168.25.255"
  result="$(get_ip_broadcast_address 192.168.25.2 255.255.255.0)"
  assertEquals "$expect" "$result"

  local result="" expect="10.10.4.111"
  result="$(get_ip_broadcast_address 10.10.4.96 255.255.255.240)"
  assertEquals "$expect" "$result"

  local result="" expect="172.20.207.255"
  result="$(get_ip_broadcast_address 172.20.206.23 255.255.252.0)"
  assertEquals "$expect" "$result"
}

test_get_ip_first_address() {
  local result="" expect="192.168.25.1"
  result="$(get_ip_first_address 192.168.25.0 255.255.255.0)"
  assertEquals "$expect" "$result"

  local result="" expect="10.10.4.97"
  result="$(get_ip_first_address 10.10.4.96 255.255.255.240)"
  assertEquals "$expect" "$result"

  local result="" expect="172.20.204.1"
  result="$(get_ip_first_address 172.20.204.0 255.255.252.0)"
  assertEquals "$expect" "$result"
}

test_get_ip_last_address() {
  local result="" expect="192.168.25.254"
  result="$(get_ip_last_address 192.168.25.255 255.255.255.0)"
  assertEquals "$expect" "$result"

  local result="" expect="10.10.4.110"
  result="$(get_ip_last_address 10.10.4.111 255.255.255.240)"
  assertEquals "$expect" "$result"

  local result="" expect="172.20.207.254"
  result="$(get_ip_last_address 172.20.207.255 255.255.252.0)"
  assertEquals "$expect" "$result"
}

test_gather_gasmask_cidr() {
  local result="" expect="27 255.255.255.224 0xffffffe0 0.0.0.31 30"
  result="$(gather_gasmask_cidr 27)"
  assertEquals "$expect" "$result"

  local result="" expect="11 255.224.0.0 0xffe00000 0.31.255.255 2097150"
  result="$(gather_gasmask_cidr 11)"
  assertEquals "$expect" "$result"
}

test_gather_gasmask_subnet() {
  local result="" expect="30 255.255.255.252 0xfffffffc 0.0.0.3 2"
  result="$(gather_gasmask_subnet 255.255.255.252)"
  assertEquals "$expect" "$result"

  local result="" expect="14 255.252.0.0 0xfffc0000 0.3.255.255 262142"
  result="$(gather_gasmask_subnet 255.252.0.0)"
  assertEquals "$expect" "$result"

  local result=""
  result="$(gather_gasmask_subnet 255.254.255.0 2>&1)"
  assertEquals "1" $?
  assert_grep "is not a valid subnet mask or wildcard bit mask!" "$result"
}

test_gather_gasmask_hex() {
  local result="" expect="20 255.255.240.0 0xfffff000 0.0.15.255 4094"
  result="$(gather_gasmask_hex 0xfffff000)"
  assertEquals "$expect" "$result"

  local result="" expect="17 255.255.128.0 0xffff8000 0.0.127.255 32766"
  result="$(gather_gasmask_hex 0xffff8000)"
  assertEquals "$expect" "$result"

  local result=""
  result="$(gather_gasmask_hex 0xfffffffx 2>&1)"
  assertEquals "1" $?
  assert_grep "is not a valid subnet mask!" "$result"
  assert_grep "Hex values need 8 chars" "$result"
}

test_gather_gasmask_wildcard() {
  local result="" expect="16 255.255.0.0 0xffff0000 0.0.255.255 65534"
  result="$(gather_gasmask_wildcard 0.0.255.255)"
  assertEquals "$expect" "$result"

  local result="" expect="27 255.255.255.224 0xffffffe0 0.0.0.31 30"
  result="$(gather_gasmask_wildcard 0.0.0.31)"
  assertEquals "$expect" "$result"

  local result=""
  result="$(gather_gasmask_wildcard 0.0.0.32 2>&1)"
  assertEquals "1" $?
  assert_grep "is not a valid subnet mask or wildcard bit mask!" "$result"
}

test_gather_gasmask_ip() {
  local result=""
  local expect="192.168.72.64 192.168.72.95 192.168.72.65 192.168.72.94"
  result="$(gather_gasmask_ip 192.168.72.79 255.255.255.224)"
  assertEquals "$expect" "$result"

  local result=""
  local expect="10.8.0.0 10.11.255.255 10.8.0.1 10.11.255.254"
  result="$(gather_gasmask_ip 10.11.12.13 255.252.0.0)"
  assertEquals "$expect" "$result"

  local result=""
  result="$(gather_gasmask_ip 172.1270.23.4 255.255.255.0 2>&1)"
  assertEquals "1" $?
  assert_grep "is not a valid IP address!" "$result"
  assert_grep "IP addresses take the form" "$result"
}

test_main() {
  local result="" expect=""
  result="$(main 24)"
  expect="$(cat << EOF

---------------------------------------------
       TCP/IP SUBNET MASK EQUIVALENTS
---------------------------------------------
CIDR = .....................: /24
Netmask = ..................: 255.255.255.0
Netmask (hex) = ............: 0xffffff00
Wildcard Bits = ............: 0.0.0.255
Usable IP Addresses = ......: 254
EOF
        )"

  assertEquals "$expect" "$result"

  local result=""
  result="$(main 42 2>&1)"
  assertEquals "1" $?
  assert_grep "CIDR notations must be a number between 0 and 32 inclusive!" \
              "$result"
}

test_get_help() {
  local result="" expect=""
  result=$(./gasmask -h)
  expect=$(cat << EOF
Usage: gasmask <netmask or ip/netmask>

Options:
  -h, --help    Show this help menu

Description: gasmask is a network configuration tool.
Examples:
$ gasmask /24
$ gasmask 255.255.255.252
$ gasmask 192.168.86.27/25
$ gasmask 4.5.6.7/0xff000000

See the README for more information, or
run "gasmask" with no arguments, or
visit https://github.com/beelleau/gasmask
EOF
        )

  assertEquals "$expect" "$result"
}

source shunit2
