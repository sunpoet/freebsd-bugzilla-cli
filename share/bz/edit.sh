Usage () {
  cat <<EOF
Usage: bz edit [-n] pr
       bz edit -h

Options:
    -h    -- this help message
    -n    -- dry run ; just echo what would be done

Args:
    pr    -- pr number

Will spawn $EDITOR and allow you to edit the fields and/or add a comment
EOF

  exit 1
}

edit_make_scratch_file () {
  local d=$1

  echo "# Any line starting with # will be ignored" > $d/pr.scratch
  echo "#" >> $d/pr.scratch

  head -18 $d/pr | tail -16 >> $d/.t
  sed -i '' -e 's,^Priority,# Priority,' $d/.t
  sed -i '' -e 's,^Reporter,# Reporter,' $d/.t
  sed -i '' -e 's,^Reported,# Reported,' $d/.t
  sed -i '' -e 's,^TargetMilestone,# TargetMilestone,' $d/.t
  sed -i '' -e 's,^Updated,# Updated,' $d/.t
  sed -i '' -e 's,^classification,# classification,' $d/.t
  sort $d/.t >> $d/pr.scratch
  rm -f $d/.t

  echo >> $d/pr.scratch
  echo "# Any lines after here will be considered an additional comment to make" >> $d/pr.scratch
  echo >> $d/pr.scratch
  echo "# UNEDITABLE attachments and comments follow" >> $d/pr.scratch
  local l=$(wc -l $d/pr | awk '{ print $1 }')
  tail -$(($l-18)) $d/pr >> $d/pr.scratch
}

edit () {
  local pr=$1
  local f_n=$2

  local d=$(_pr_dir $pr)
  ${ME} get -n $pr

  edit_make_scratch_file $d

  cp $d/pr.scratch $d/pr.scratch.orig
  $EDITOR $d/pr.scratch > /dev/tty

  if ! cmp -s $d/pr.scratch $d/pr.scratch.orig; then
      local assigned_to=$(_field_changed 'AssignedTo' $d/pr.scratch.orig $d/pr.scratch)
      local component=$(_field_changed   'Component'  $d/pr.scratch.orig $d/pr.scratch)
      local hardware=$(_field_changed    'Hardware'   $d/pr.scratch.orig $d/pr.scratch)
      local product=$(_field_changed     'Product'    $d/pr.scratch.orig $d/pr.scratch)
      local resolution=$(_field_changed  'Resolution' $d/pr.scratch.orig $d/pr.scratch)
      local state=$(_field_changed       'Status'     $d/pr.scratch.orig $d/pr.scratch)
      local severity=$(_field_changed    'Severity'   $d/pr.scratch.orig $d/pr.scratch)
      local title=$(_field_changed       'Title'      $d/pr.scratch.orig $d/pr.scratch)
      local version=$(_field_changed     'Version'    $d/pr.scratch.orig $d/pr.scratch)

      ## find comment if any
      local s=$(grep -n "# Any lines after here will be considered an additional comment to make" $d/pr.scratch | sed -e 's,:.*,,')
      local e=$(grep -n "# UNEDITABLE attachments and comments follow" $d/pr.scratch | sed -e 's,:.*,,')
      local comment=$(head -$(($e-1)) $d/pr.scratch | tail -$(($e-$s-1)))

      backend_edit $pr $f_n "$assigned_to" "$component" "$hardware" "$product" \
                   "$resolution" "$state" "$severity" "$title" "$version" "$comment"
  fi

  rm -f $d/pr.scratch $d/pr.scratch.orig
}

. ${BZ_BACKENDDIR}/edit.sh
. ${BZ_SCRIPTDIR}/_util.sh

f_n=0
while getopts hn FLAG; do
  case ${FLAG} in
    n) f_n=1 ;;
    h) usage ;;
  esac
done
shift $(($OPTIND-1))

pr=$1

edit $pr $f_n