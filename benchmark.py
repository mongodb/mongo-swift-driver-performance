# this script should be run as `swift test | python benchmark.py`

import re
import sys

output = sys.stdin.read()
results = filter(lambda x: "median time" in x, output.split('\n'))

benchmarks = {}
for r in results:
	match = re.search(r"\[.*\ (?P<name>.*)]: median time (?P<seconds>.*) seconds, score (?P<score>.*) ", r)
	name = match.group("name")
	time = match.group("seconds")
	score = match.group("score")
	benchmarks[name] = {"time": float(time), "score": float(score)}

print "\n"
print benchmarks