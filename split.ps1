$users = Import-Csv '\\gondor\Admin\Student Lists\TDM\2021_Sem1_Students.csv'
Foreach ($user in $users){
    $name = ($user.'Student Name').Split(" ")
    $title = $name[0]
    $first = $name[1]    
    $last = $name[$name.Count -1]
    $middle = ($user.'Student Name').Substring($title.Length + $first.Length + 2).trim()    
    "$($user.'Student ID'), $title, $first, $middle, $last, $($user.Group)" >> '\\gondor\Admin\Student Lists\TDM\2021_Sem1_Students_v2.csv'
}