$Users = Get-ADGroupMember AWE6 
foreach($user in $Users){
    $u = Get-ADUser -Identity $user -Properties Description    
    $s = $u.Description.split(" ")
    "$($s[0]),$($s[1]),$($s[2]),$($s[3])" >> outfile.csv
}