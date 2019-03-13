#!/bin/sh
cd "$(realpath "$(dirname "$0")")" || exit 1

ret=0
for dir in */; do
	echo ":: $dir"
	(APORTS="$PWD/$dir" ../relgroup-check.sh; echo "exit code: $?") > "$dir/current_output"
	if [ "$UPDATE" = "1" ]; then
		mv "$dir/current_output" "$dir/expected_output"
		echo "Updated expected_output"
	elif diff -u "$dir/expected_output" "$dir/current_output"; then
		echo "Test passed"
	else
		ret=1
		echo "Test failed"
	fi
done

echo "---"
if [ "$ret" = 1 ]; then
	echo "NOTE: set UPDATE=1 to update the output"
	echo "Test failures!"
elif [ "$UPDATE" = 1 ]; then
	echo "All test output updated"
else
	echo "All tests passed"
fi

exit "$ret"
