#!/usr/bin/env bats
#
# Basic tests for Lab 3 
#
# @author: Navarro Torres, Agustín
# @email: agusnt@unizar.es
#
# @version: 0.0.1

FILE="$(realpath "${BATS_TEST_DIRNAME}/../../src/Pr4/practica4.sh")"

# Set this var with the virtual machine ips
export IPS=("192.168.56.10" "192.168.56.11")

load "../common.sh"

@test "Script ($FILE) exists" {
  # Read the head
  [ -f "$FILE" ]
  [ -s "$FILE" ]
}

@test "Check the shellbang" {
  # Check if the shellbang is right
  run check_shellbang "$FILE"
  echo "$output"
  [ "$status" -eq 0 ] 
}

@test "Check students name" {
  # Read the head
  run check_students "$FILE"
  echo "$output"
  [ "$status" -eq 0 ] 
}

@test "Create user" {

  for ip_ in "${IPS[@]}"; do
    ssh "$ip_" "sudo touch /etc/skel/test"
  done

  echo "asTest1,asTest1,asNameTest1" > "$TMP_FILE"
  echo "asTest3,asTest3,asNameTest3" >> "$TMP_FILE"
  echo "asTest4,asTest4,asNameTest4" >> "$TMP_FILE"

  run "$FILE" "-a" "$TMP_FILE" "$TMP_ADDR"
  [ ! -z "$output" ]

  for i in "${!lines[@]}"; do
    line=$(("$i" + 1))
    user=$(awk -v l="$line" "NR==l" "$TMP_FILE" | cut -d',' -f1)
    REGEX="(.*$user.*creado.*)"
    if ! grep -q -E -i "$REGEX" <<< "${lines[$i]}"; then 
      >&2 echo "Expected output for $user is: \"$user ha sido creado\", the actual output is ${lines[$i]}"
      exit
    fi
  done
}

@test "Cannot create duplicate users" {
  TMP_FILE="$TMP_FOLDER/create"
  echo "asTest1,asTest1,asNameTest1" > "$TMP_FILE"
  echo "asTest3,asTest3,asNameTest3" >> "$TMP_FILE"
  echo "asTest4,asTest4,asNameTest4" >> "$TMP_FILE"

  run "$FILE" "-a" "$TMP_FILE" "$TMP_ADDR"
  [ ! -z "$output" ]

  for i in "${!lines[@]}"; do
    line=$(("$i" + 1))
    user=$(awk -v l="$line" "NR==l" "$TMP_FILE" | cut -d',' -f1)
    REGEX="(.*$user.*existe.*)"
    if ! grep -q -E -i "$REGEX" <<< "${lines[$i]}"; then 
      >&2 echo "Expected output for $user is: \"El usuario $user ya existe\", the actual output is ${lines[$i]}"
      exit
    fi
  done
}

@test "Create users again with no valid entries" {
  TMP_FILE="$TMP_FOLDER/create"
  echo "asTest1,asTest1,asNameTest1" > "$TMP_FILE"
  echo "asTest2,," >> "$TMP_FILE"
  echo "asTest2,asTest2,asNameTest2" >> "$TMP_FILE"

  run "$FILE" "-a" "$TMP_FILE" "$TMP_ADDR"
  [ ! -z "$output" ]

  user=$(awk "NR==1" "$TMP_FILE" | cut -d',' -f1)
  REGEX="(.*$user.*existe.*)"
  if ! grep -q -E -i "$REGEX" <<< "${lines[0]}"; then 
    >&2 echo "Expected output for $user is: \"El usuario $user ya existe\", the actual output is ${lines[0]}"
    exit
  fi
  user=$(awk "NR==2" "$TMP_FILE" | cut -d',' -f1)
  REGEX="(.*invalido.*)"
  if ! grep -q -E -i "$REGEX" <<< "${lines[1]}"; then 
    >&2 echo "Expected output for $user is: \"Campo invalido\", the actual output is ${lines[1]}"
    exit
  fi
  user=$(awk "NR==3" "$TMP_FILE" | cut -d',' -f1)
  REGEX="(.*$user.*creado.*)"
  if ! grep -q -E -i "$REGEX" <<< "${lines[2]}"; then 
    >&2 echo "Expected output for $user is: \"$user ha sido creado\", the actual output is ${lines[2]}"
    exit
  fi
}

@test "Check that users are really created in the system" {
  userNames=("asTest1" "asTest2" "asTest3" "asTest4")

  for ip_ in "${IPS[@]}"; do
    for user in "${userNames[@]}"; do
      run ssh "$ip_" "sudo bash -s" -- "$user" << 'EOF'
        if ! sudo grep -q -E -i "$1" "/etc/shadow"; then 
          >&2 echo "Some user(s) is not really created in the system"
          exit 1
        fi
        exit 0
EOF
      if [ "$status" -ne 0 ]; then
        >&2 echo "$output on IP: $ip_"
        exit
      fi
    done
  done
}

@test "Password of new users will expire in 30 days" {
  userNames=("asTest1" "asTest2" "asTest3" "asTest4")

  for ip_ in "${IPS[@]}"; do
    for user in "${userNames[@]}"; do
      run ssh "$ip_" "sudo bash -s" -- "$user" << 'EOF'
        days=$(getent shadow "$1" | cut -d: -f5) 
        if [[ "$days" -ne 30 ]]; then
          >&2 echo "The password of user $1 expire in $days days instead of 30"
          exit 1
        fi
        exit 0
EOF
      if [ "$status" -ne 0 ]; then
        >&2 echo "$output on IP: $ip_"
        exit
      fi
    done
  done
}

@test "Default group is the same that the user" {
  userNames=("asTest1" "asTest2" "asTest3" "asTest4")

  for ip_ in "${IPS[@]}"; do
    for user in "${userNames[@]}"; do
      run ssh "$ip_" "sudo bash -s" -- "$user" << 'EOF'
        defaultG=$(sudo id -gn "$1")
        if [[ "$1" != "$defaultG" ]]; then
          >&2 echo "Default group of $1 is $defaultG instead of $user"
          exit 1
        fi
      exit 0
EOF
      if [ "$status" -ne 0 ]; then
        >&2 echo "$output on IP: $ip_"
        exit
      fi
    done
  done
}

@test "News home has the same content that /etc/skel" {
  userNames=("asTest1" "asTest2" "asTest3" "asTest4")

  for ip_ in "${IPS[@]}"; do
    for user in "${userNames[@]}"; do
      run ssh "$ip_" "sudo bash -s" -- "$user" << 'EOF'
          diffValue=$(sudo diff -r /etc/skel/ /home/"$1/")
          if [ ! -z "$diffValue" ]; then
            >&2 echo "/home/$1 and /etc/skel differs: $diffValue"
            exit 1
          fi
        exit 0
EOF
      if [ "$status" -ne 0 ]; then
        >&2 echo "$output on IP: $ip_"
        exit
      fi
    done
  done
}

@test "Delete user that does not exits" {
  TMP_FILE="$TMP_FOLDER/del"
  echo "asTest99," > "$TMP_FILE"
  
  run "$FILE" "-s" "$TMP_FILE" "$TMP_ADDR"
  if [ ! -z "$output" ]; then
    >&2 echo "I expect no output when try to delete an user that does not exists, and I get: $output"
    exit
  fi
}

@test "Delete users" {
  TMP_FILE="$TMP_FOLDER/del"
  echo "asTest1," > "$TMP_FILE"
  echo "asTest2," >> "$TMP_FILE"
  echo "asTest3," >> "$TMP_FILE"
  echo "asTest4," >> "$TMP_FILE"
  
  run "$FILE" "-s" "$TMP_FILE" "$TMP_ADDR"

  userNames=("asTest1" "asTest2" "asTest3" "asTest4")

  for ip_ in "${IPS[@]}"; do
    for user in "${userNames[@]}"; do
      run ssh "$ip_" "sudo bash -s" -- "$user" << 'EOF'
        if sudo grep -q -E -i "$1" "/etc/shadow"; then 
          >&2 echo "Some user(s) is still in the system"
          exit 1
        else
          exit 0
        fi
EOF
      if [ "$status" -ne 0 ]; then
        >&2 echo "$output on IP: $ip_"
        exit
      fi
    done
  done
}

@test "The home of the users are removed" {
  userNames=("asTest1" "asTest2" "asTest3" "asTest4")

  for ip_ in "${IPS[@]}"; do
    for user in "${userNames[@]}"; do
      run ssh "$ip_" "sudo bash -s" -- "$user" << 'EOF'
        if [ -d "/home/$1" ]; then
          >&2 echo "/home/$1 still exists"
          exit 1
        else
          exit 0
        fi
EOF
      if [ "$status" -ne 0 ]; then
        >&2 echo "$output on IP: $ip_"
        exit
      fi
    done
  done
}

@test "/extra/backup exists" {
  for ip_ in "${IPS[@]}"; do
    run ssh "$ip_" "sudo bash -s" -- "$user" << 'EOF'
      [ ! -d /extra/backup ] && exit 1
      exit 0
EOF
    if [ "$status" -ne 0 ]; then
      exit
    fi
  done
}

@test "The home of users have backup in /extra/backup" {
  userNames=("asTest1" "asTest2" "asTest3" "asTest4")

  for ip_ in "${IPS[@]}"; do
    for user in "${userNames[@]}"; do
      run ssh "$ip_" "sudo bash -s" -- "$user" << 'EOF'
        if [ ! -f "/extra/backup/$1.tar" ]; then
          >&2 echo "/extra/backup/$1.tar does not exist"
          exit 1
        fi
        exit 0
EOF
      if [ "$status" -ne 0 ]; then
        >&2 echo "$output"
        exit
      fi
    done
  done
}

@test "Backup has some content" {
  userNames=("asTest1" "asTest2" "asTest3" "asTest4")

  for ip_ in "${IPS[@]}"; do
    for user in "${userNames[@]}"; do
      run ssh "$ip_" "sudo bash -s" -- "$user" << 'EOF'
        foo=$(tar -tf /extra/backup/"$1".tar | wc -l)
        if [ "$foo" -eq 0 ]; then
          >&2 echo "/extra/backup/$1.tar is empty"
          exit 1
        fi
        exit 0
EOF
      if [ "$status" -ne 0 ]; then
        >&2 echo "$output"
        exit
      fi
    done
  done
}

@test "/extra/backup is created even if not user is deleted" {
  TMP_FILE="$TMP_FOLDER/del"
  echo "asTest1," > "$TMP_FILE"
  echo "asTest2," >> "$TMP_FILE"
  echo "asTest3," >> "$TMP_FILE"
  echo "asTest4," >> "$TMP_FILE"

  for ip_ in "${IPS[@]}"; do
    run ssh "$ip_" "sudo bash -s" << 'EOF'
      [ -d /extra/backup ] && sudo rm -rf /extra/backup
      
      run sudo "$FILE" "-s" "$TMP_FILE"

      [ -d /extra/backup ] 

      # Clean system
      sudo rm -rf /extra/backup
      sudo rm /etc/skel/test
EOF
  done
}

@test "Machine is not available" {
  TMP_FILE="$TMP_FOLDER/del"
  echo "asTest1," > "$TMP_FILE"
  echo "asTest2," >> "$TMP_FILE"
  echo "asTest3," >> "$TMP_FILE"
  echo "asTest4," >> "$TMP_FILE"

  echo "192.168.122.55" > "$TMP_ADDR"

  run "$FILE" "-s" "$TMP_FILE" "$TMP_ADDR"

  REGEX="(.*$addr.*no.*accesible.*)"
  if ! grep -q -E -i "$REGEX" <<< "${lines[$i]}"; then 
    echo $output
    exit
  fi
}
