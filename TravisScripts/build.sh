# Set project path
project_path=$(pwd)/ncmb_unity
# Log file path
log_file=$(pwd)/TravisScripts/unity_build.log
# Unity command path
unity_command=/Applications/Unity/Unity.app/Contents/MacOS/Unity
# Error code
error_code=0
build_error=1
test_error=1
# Config for retry 
max_retry=1
# Build and Test count
build_count=0
test_count=0


# UNITY BUILD WITH RETRY 
while [[ $build_count -lt $((max_retry+1)) && $build_error != 0 ]]
do
echo "* Building project for Mac OS."
$unity_command \
  -batchmode \
  -nographics \
  -silent-crashes \
  -logFile "$log_file" \
  -projectPath "$project_path" \
  -quit
if [ $? = 0 ] ; then
  echo "* Building Mac OS completed successfully" 
  build_error=0
else
  echo "* Building Mac OS failed with $?"
  build_error=1
fi

if [ $build_count -lt $((max_retry+1)) ]; then
  build_count=$((build_count+1))
fi

done
echo "* Unity build log"
cat $log_file 

if [ $build_error != 0 ]; then
  echo "x Building Mac OS completed failed. Retry: $((build_count-1))"
  echo "x Please fix MacOS Building before running Test Runner"
  exit $build_error
fi

# TEST RUNNER WITH RETRY 
test_result_file=/Users/VITALIFY/ncmb_unity/TravisScripts/test_runner_result.xml
while [[ $test_count -lt $((max_retry+1)) && $test_error != 0 ]]
do
echo "* Execute Test Runner"
$unity_command \
-runTests \
-projectPath "$project_path" \
-testResults "$test_result_file" \
-testPlatform editmode

failed=$(echo 'cat //test-run/@failed' | xmllint --shell $test_result_file | awk -F\" 'NR % 2 == 0 { print $2 }')

if [[ -z $failed && $failed -gt 0 ]];
then
  test_error=2
else 
  test_error=0
fi

if [ $test_count -lt $((max_retry+1)) ]; then
  test_count=$((test_count+1))
fi
done

echo '* Test Runner result'
cat $test_result_file 

total=$(echo 'cat //test-run/@total' | xmllint --shell $test_result_file | awk -F\" 'NR % 2 == 0 { print $2 }')
passed=$(echo 'cat //test-run/@passed' | xmllint --shell $test_result_file | awk -F\" 'NR % 2 == 0 { print $2 }')
failed=$(echo 'cat //test-run/@failed' | xmllint --shell $test_result_file | awk -F\" 'NR % 2 == 0 { print $2 }')

if [[ -z $total ]]; then
  test_error=3
fi

echo "______________________________________________________________________"
echo "o Building Mac OS completed successfully. Retry: $((build_count-1))"
case "$test_error" in
0)  echo "o Test Runner completed successfully [ Total:$total  Passed:$passed Failed:$failed ]. Retry: $((test_count-1))"
    ;;
2)  echo "x Test Runner completed failed [ Total:$total  Passed:$passed Failed:$failed ]. Retry: $((test_count-1))"
    ;;
3)  echo "x Test Runner completed failed. Can not read xml result file"
    ;;
esac
exit $test_error
