@* =====================================================================
@  qsort.w  ---  Literate C template for the "Elite Generalist" toolkit.
@  ---------------------------------------------------------------------
@  This file is the canonical example of Phase 3 in the pipeline:
@  the source of truth is ONE document, half prose, half code.
@
@  The C preprocessor never sees this file.  Instead, two tools run:
@    * ctangle  -- extracts the C program (qsort.c) from this file.
@    * cweave   -- extracts the TeX/HTML manual (qsort.tex, qsort.html).
@
@  Same source. Two artifacts. Zero documentation drift.
@
@  To build:
@      ctangle qsort.w        # -> qsort.c
@      cc -O2 qsort.c -o qsort
@      cweave  qsort.w        # -> qsort.tex  (then pdflatex it)
@  =====================================================================
@

@<Include@>=
@=#include <stdio.h>
@=#include <stdlib.h>
@=#include <string.h>
@=

@ The program reads newline-separated integers from stdin and prints them
@ sorted.  The whole program is six paragraphs of prose and six lines of
@ actual code.  Compare that with a typical ``qsort.c'' file plus its
@ README plus its man page plus its design doc --- four files, all of
@ which rot independently.

@* The main routine.
@ We open stdin, allocate a small growable array, read every integer
@ (skipping malformed lines), call the recursive quicksort, and print
@ the result one number per line.
@<main@>=
@=int main(void)@+{@+
@=    int   *a = NULL;@+
@=    size_t n = 0, cap = 0;@+
@=    int   x;@+
@=    while (scanf("%d", &x) == 1) {@+
@=        if (n == cap) {@+
@=            cap = cap ? cap * 2 : 16;@+
@=            a   = realloc(a, cap * sizeof *a);@+
@=            if (!a) { perror("realloc"); return 1; }@+
@=        }@+
@=        a[n++] = x;@+
@=    }@+
@=    @<Partition@>@+
@=    for (size_t i = 0; i < n; i++) printf("%d\n", a[i]);@+
@=    free(a);@+
@=    return 0;@+
@=}
@=

@* Partition.
@ Hoare's partition scheme.  We pick the LAST element as pivot; this
@ is a deliberate teaching choice (Knuth, TAOCP Vol 3, Sec 5.2.2).
@ The indices |lo| and |hi| bracket the slice to be partitioned.
@ On return, all of a[lo..i] are <= pivot and all of a[i+1..hi] are >.
@<Partition@>=
@=void sort(int *a, size_t lo, size_t hi)@+{@+
@=    if (lo + 1 >= hi) return;       /* 0 or 1 element: already sorted. */@+
@=    int pivot = a[hi - 1];@+
@=    size_t i = lo;@+
@=    for (size_t j = lo; j < hi - 1; j++)@+
@=        if (a[j] <= pivot) {@+
@=            int t = a[i]; a[i] = a[j]; a[j] = t;@+
@=            i++;@+
@=        }@+
@=    int t = a[i]; a[i] = a[hi - 1]; a[hi - 1] = t;@+
@=    if (i      > lo) sort(a, lo, i);@+
@=    if (hi - 1 > i)   sort(a, i + 1, hi);@+
@=}
@=

@* The whole program.
@ A literate C file may have a ``complete program'' section that
@ ctangle assembles.  Reading this, a human sees the design before
@ the code; reading qsort.c, a compiler sees the code without noise.
@ Two audiences, one source, zero drift.
@<qsort.c@>=
@(@<Include@>)
@(@<main@>)
@(@<Partition@>)
@=
