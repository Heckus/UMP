set -e
f() {
    false
    echo "f continued"
}
set +e
(
    set -e
    f
)
exit_code=$?
set -e
echo "exit code $exit_code"
