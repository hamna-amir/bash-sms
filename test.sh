#!/bin/bash

# File to store student data
DATA_FILE="students.db"

# Arrays to store student-level data
declare -a student_names
declare -a student_roll_nos
declare -A student_credentials
declare -A student_courses

# Teacher credentials
declare -A teacher_credentials
teacher_credentials["teacher1"]="123"

# ------------------- File Handling ----------------------

load_data() {
    if [[ ! -f $DATA_FILE ]]; then return; fi
    while IFS='|' read -r roll name password course_data; do
        student_names+=("$name")
        student_roll_nos+=("$roll")
        student_credentials["$roll"]="$password"
        student_courses["$roll"]="$course_data"
    done < "$DATA_FILE"
}

save_data() {
    > "$DATA_FILE"
    for i in "${!student_roll_nos[@]}"; do
        roll="${student_roll_nos[$i]}"
        name="${student_names[$i]}"
        password="${student_credentials[$roll]}"
        courses="${student_courses[$roll]}"
        echo "$roll|$name|$password|$courses" >> "$DATA_FILE"
    done
}

# -------------------------------------------------------

grade_student() {
    local obtained=$1
    local total=$2
    if ((total == 0)); then echo "F"; return; fi
    local percentage=$((obtained * 100 / total))
    if ((percentage >= 85)); then echo "A"
    elif ((percentage >= 70)); then echo "B"
    elif ((percentage >= 50)); then echo "C"
    elif ((percentage >= 40)); then echo "D"
    else echo "F"; fi
}

grade_to_gpa() {
    local grade=$1
    case $grade in
        A) echo 4.0 ;;
        B) echo 3.0 ;;
        C) echo 2.0 ;;
        D) echo 1.0 ;;
        *) echo 0.0 ;;
    esac
}

calculate_cgpa_for_roll() {
    local roll=$1
    local total_gpa=0.0
    local course_count=0
    IFS=';' read -ra courses <<< "${student_courses[$roll]}"
    for course in "${courses[@]}"; do
        IFS=',' read -r code obtained total grade <<< "$course"
        gpa=$(grade_to_gpa "$grade")
        total_gpa=$(awk -v t="$total_gpa" -v g="$gpa" 'BEGIN { print t + g }')
        ((course_count++))
    done
    if ((course_count > 0)); then
        awk -v total="$total_gpa" -v count="$course_count" 'BEGIN { printf "%.2f\n", total / count }'
    else
        echo 0.0
    fi
}

add_student() {
    # Check if there are already 20 students
    if (( ${#student_roll_nos[@]} >= 20 )); then
        echo "Error: Cannot add more than 20 students!"
        return
    fi

    read -p "Enter student name: " name
    read -p "Enter Roll No: " roll_no

    # Check if the roll number already exists
    for existing_roll in "${student_roll_nos[@]}"; do
        if [[ "$existing_roll" == "$roll_no" ]]; then
            echo "Error: Roll number $roll_no already exists!"
            return
        fi
    done

    if ! [[ "$roll_no" =~ ^[0-9]+$ ]] || ((roll_no < 0)); then
        echo "Invalid roll number. It must be a non-negative number."
        return
    fi
    read -sp "Set Password for Student: " password
    echo
    student_names+=("$name")
    student_roll_nos+=("$roll_no")
    student_credentials["$roll_no"]="$password"
    student_courses["$roll_no"]=""
   
    read -p "Enter number of subjects: " num_subjects
    for ((i = 1; i <= num_subjects; i++)); do
        echo "Enter details for subject $i"
        read -p "Course Code: " code
        read -p "Obtained Marks: " obtained
        read -p "Total Marks: " total
        if ((obtained < 0 || total <= 0)); then
            echo "Invalid marks. Obtained and total marks must be non-negative, and total must be greater than 0."
            ((i--))
            continue
        fi
        grade=$(grade_student "$obtained" "$total")
        entry="$code,$obtained,$total,$grade"
        student_courses["$roll_no"]+="$entry;"
    done
    echo "Student added successfully!"
    save_data
}

update_student() {
    read -p "Enter Roll No of student to update: " roll
    index=-1
    for i in "${!student_roll_nos[@]}"; do
        if [[ "${student_roll_nos[$i]}" == "$roll" ]]; then
            index=$i
            break
        fi
    done
    if ((index == -1)); then
        echo "Student with Roll No $roll not found."
        return
    fi

    echo -e "\nUpdate Menu for $roll"
    echo "1. Update Name"
    echo "2. Update Password"
    echo "3. Update Grades"
    read -p "Choice: " choice

    case $choice in
        1)
            read -p "Enter new name: " new_name
            student_names[$index]="$new_name"
            echo "Name updated."
            ;;
        2)
            read -sp "Enter new password: " new_pass
            echo
            student_credentials["$roll"]="$new_pass"
            echo "Password updated."
            ;;
        3)
            IFS=';' read -ra courses <<< "${student_courses[$roll]}"
            for i in "${!courses[@]}"; do
                IFS=',' read -r code obtained total grade <<< "${courses[$i]}"
                echo "Updating $code"
                read -p "New Obtained Marks (was $obtained): " new_obtained
                read -p "New Total Marks (was $total): " new_total
                if ((new_obtained < 0 || new_total <= 0)); then
                    echo "Invalid marks. Obtained and total marks must be non-negative, and total must be greater than 0."
                    continue
                fi
                new_grade=$(grade_student "$new_obtained" "$new_total")
                courses[$i]="$code,$new_obtained,$new_total,$new_grade"
            done
            student_courses["$roll"]="$(IFS=';'; echo "${courses[*]}")"
            echo "Grades updated."
            ;;
        *)
            echo "Invalid choice!"
            ;;
    esac
    save_data
}

delete_student() {
    read -p "Enter Roll No of student to delete: " roll
    index=-1
    for i in "${!student_roll_nos[@]}"; do
        if [[ "${student_roll_nos[$i]}" == "$roll" ]]; then
            index=$i
            break
        fi
    done
    if ((index == -1)); then
        echo "Student with Roll No $roll not found."
        return
    fi
    unset 'student_names[index]'
    unset 'student_roll_nos[index]'
    unset "student_credentials[$roll]"
    unset "student_courses[$roll]"
    student_names=("${student_names[@]}")
    student_roll_nos=("${student_roll_nos[@]}")
    echo "Student $roll deleted."
    save_data
}

display_students_by_filter() {
    local filter=$1
    for i in "${!student_roll_nos[@]}"; do
        roll=${student_roll_nos[$i]}
        name=${student_names[$i]}
        IFS=';' read -ra courses <<< "${student_courses[$roll]}"
        pass_count=0
        fail_count=0
        for course in "${courses[@]}"; do
            IFS=',' read -r code obtained total grade <<< "$course"
            if [[ "$grade" == "F" ]]; then
                ((fail_count++))
            else
                ((pass_count++))
            fi
        done
        case $filter in
            all) show=1 ;;
            passed) ((fail_count == 0)) && show=1 || show=0 ;;
            failed) ((fail_count > 0)) && show=1 || show=0 ;;
        esac
        if ((show == 1)); then
            echo -e "\nName: $name"
            echo "Roll No: $roll"
            printf "%-10s %-15s %-15s %-10s\n" "Code" "Obtained" "Total" "Grade"
            for course in "${courses[@]}"; do
                IFS=',' read -r code obtained total grade <<< "$course"
                printf "%-10s %-15s %-15s %-10s\n" "$code" "$obtained" "$total" "$grade"
            done
            cgpa=$(calculate_cgpa_for_roll "$roll")
            echo "CGPA: $cgpa"
        fi
    done
}

student_login() {
    read -p "Enter Roll No: " roll_no
    read -sp "Enter password: " password
    echo
    if [[ "${student_credentials[$roll_no]}" == "$password" ]]; then
        echo "Login successful! Welcome, $roll_no."
        while true; do
            echo -e "\nStudent Menu"
            echo "1. View Grades"
            echo "2. View CGPA"
            echo "3. Exit"
            read -p "Enter your choice: " choice
            case $choice in
                1)
                    IFS=';' read -ra courses <<< "${student_courses[$roll_no]}"
                    sorted=($(for course in "${courses[@]}"; do echo "$course"; done | sort))
                    printf "%-10s %-15s %-15s %-10s\n" "Code" "Obtained" "Total" "Grade"
                    for course in "${sorted[@]}"; do
                        IFS=',' read -r code obtained total grade <<< "$course"
                        printf "%-10s %-15s %-15s %-10s\n" "$code" "$obtained" "$total" "$grade"
                    done ;;
                2)
                    cgpa=$(calculate_cgpa_for_roll "$roll_no")
                    echo "CGPA: $cgpa" ;;
                3) break ;;
                *) echo "Invalid choice!" ;;
            esac
        done
    else
        echo "Invalid Roll No or password."
    fi
}

teacher_login() {
    read -p "Enter Teacher ID: " teacher_id
    read -sp "Enter password: " password
    echo
    if [[ "${teacher_credentials[$teacher_id]}" == "$password" ]]; then
        echo "Login successful! Welcome, Teacher $teacher_id."
        while true; do
            echo -e "\nTeacher Menu"
            echo "1. Add Student"
            echo "2. Delete Student"
            echo "3. Update Student"
            echo "4. Display Students"
            echo "5. Exit"
            read -p "Enter your choice: " choice
            case $choice in
                1) add_student ;;
                2) delete_student ;;
                3) update_student ;;
                4)
                    echo -e "\nDisplay Menu"
                    echo "1. Display All Students"
                    echo "2. Display Passed Students"
                    echo "3. Display Failed Students"
                    echo "4. Back"
                    read -p "Enter your choice: " dchoice
                    case $dchoice in
                        1) display_students_by_filter "all" ;;
                        2) display_students_by_filter "passed" ;;
                        3) display_students_by_filter "failed" ;;
                        4) ;; # back
                        *) echo "Invalid choice!" ;;
                    esac ;;
                5) break ;;
                *) echo "Invalid choice!" ;;
            esac
        done
    else
        echo "Invalid Teacher ID or password."
    fi
}

# ------------------- Main ---------------------
load_data
while true; do
    echo -e "\nWelcome to the Student Management System"
    echo "1. Student Login"
    echo "2. Teacher Login"
    echo "3. Exit"
    read -p "Enter your choice: " choice
    case $choice in
        1) student_login ;;
        2) teacher_login ;;
        3) save_data; exit ;;
        *) echo "Invalid choice!" ;;
    esac
done
