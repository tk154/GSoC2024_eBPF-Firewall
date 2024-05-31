#!/usr/bin/awk -f

function proc_stats(lines) {
    file = "/proc/stat"
    regex = "^cpu[0-9]+ "

    getline line < file

    for (i = 1; ; i++) {
        getline line < file

        if (line !~ regex)
            break

        sub(regex, "", line)
        lines[i] = line
    }

    close(file)
}

BEGIN {
    print "unix,cpu,user,nice,system,idle,iowait,irq,softirq,steal,guest,guest_nice"
    proc_stats(old_lines)

    while (1) {
        if (system("sleep 1 && exit 1") != 1)
            break

        unix = systime()
        proc_stats(new_lines)

        for (i = 1; i <= length(new_lines); i++) {
	        split(old_lines[i], old_line)
            split(new_lines[i], new_line)
            total_diff = 0

            for (j = 1; j <= length(new_line); j++) {
                diff = new_line[j] - old_line[j]

                diffs[j] = diff
                total_diff += diff
            }

            scale = 100.0 / total_diff
            printf "%u,%u", unix, i

            for (j = 1; j <= length(diffs); j++)
                printf ",%.2f", diffs[j] * scale
            print

            old_lines[i] = new_lines[i]
        }
    }
}
