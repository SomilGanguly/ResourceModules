##
## The script works with YmlCurater pipeline and Curated-YmlFile script.
## The script helps in manipulating data passed in the $array
## from Curated-YmlFile script to form YmlFileObjects.
## This script gets called twice (first time for deploy file and second for parameter file) 
## in Curated-YmlFile script to help build
## on default array in case of multiple instances of a resource type.
## 
Install-Module powershell-yaml -Force

function Create-YmlFileObject {
        param (
        [PSCustomObject]
        $array,
        [string]
        $objectname
    )
$commonarray=@()
$firstInArray=$array[0]
$yaml = @"
  default:
  - $firstInArray
"@

$obj = ConvertFrom-Yaml $yaml
$obj1=ConvertTo-Yaml -JsonCompatible $obj

$obj2=$obj1 | ConvertFrom-Json
for ($num = 1 ; $num -lt $array.Count ; $num++)
{
  $obj2.default += $array[$num]
}


$yaml1 = @"
- name: $objectname
  type: object
"@
$root= ConvertFrom-Yaml $yaml1
$root1=ConvertTo-Yaml -JsonCompatible $root
$root2=$root1 | ConvertFrom-Json
$commonarray += $root2
$commonarray += $obj2

$a=$commonarray | ConvertTo-Yaml

## Replacing "-" with "" to follow Yaml syntax rules
$find="-"
$replace=" "
$string=$a
$position=$string.IndexOf($find, $string.IndexOf($find)+1)

if ($pos -ne -1)
{
   "{0}{1}{2}" -f $string.Substring(0, $position), $replace, $string.Substring($position + $find.Length) 
}
else
{
   $string 
}
}
