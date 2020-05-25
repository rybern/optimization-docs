
# Table of Contents

1.  [Optimization levels](#orgdcb25a9)
2.  [Optimization documentation](#orgddc2d55)
    1.  [Function inlining](#org951385b)
    2.  [Static loop unrolling](#orgdccffb8)
    3.  [One step loop unrolling](#org2a4947e)
    4.  [Constant propagation](#org2036c36)
    5.  [Expression propagation](#org5c810bc)
    6.  [Copy propagation](#org76cd4f4)
    7.  [Dead code elimination](#orgdd99c0a)
    8.  [Partial evaluation](#org11fafb9)
    9.  [Lazy code motion](#orgec8beaf)
    10. [Auto-differentiation level optimization](#org6c7e9be)

The Stanc3 compiler can attempt to optimize a Stan program as it is compiled.

The optimized program has the same behavior as the unoptimized program, but it may be faster, more memory efficient, or more numerically stable.

This section introduces the available optimization options and describes their effect.

You can see a printout of a representation of the Stan program after the optimizations have been applied with the Stanc3 command-line option `--debug-optimized-mir-pretty`.
You can see an analogous representation of the program before optimizations have been applied with `--debug-transformed-mir-pretty`.


<a id="orgdcb25a9"></a>

# Optimization levels

To turn on optimizations, the user specifies the desired optimization *level*.
The level specifies the set of optimizations which are turned on.
Optimizations which are turned on are then applied in a specific order, and some are applied repeatedly.

Optimization levels are specified by the numbers 0-4:

-   **0**
    No optimizations are applied.
-   **1**
    Only optimizations which are simple to understand, do not dramatically change the program, and are unlikely noticeably slow down compile times are applied.
-   **2**
    All optimizations which are unlikely to be numerically different than the unoptimized program are applied.
    Some code transformations, such as replacing `log(1-x)` with the builtin `log1m(x)`, may result in slight numerical differences that are detectable when sampling from the program with a fixed random seed.
    Those transformations are avoided.
-   **3**
    All optimizations are applied.

The levels include these optimizations:

-   **0**
    None
-   **1**
    -   Dead code elimination
    -   Auto-differentiation level optimization
-   **2**
    
    -   Function inlining\*
    -   Static loop unrolling
    -   One step loop unrolling
    -   Constant propagation\*
    -   Expression propagation\*
    -   Copy propagation\*
    -   Dead code elimination
    -   Partial evaluation\*
    -   Lazy code motion\*
    -   Auto-differentiation level optimization
    
    \*: A more numerically stable version of this optimization.
-   **3**
    -   Function inlining
    -   Static loop unrolling
    -   One step loop unrolling
    -   Constant propagation
    -   Expression propagation
    -   Copy propagation
    -   Dead code elimination
    -   Partial evaluation
    -   Lazy code motion
    -   Auto-differentiation level optimization


<a id="orgddc2d55"></a>

# Optimization documentation


<a id="org951385b"></a>

## DONE Function inlining

Function inlining replaces each function call to each user-defined function `f` with the body of `f`.
It does this by copying the function body to the call site and doing the appropriate renaming of the argument variables.
This can speed up a program by avoiding the overhead of a function call and providing more opportunities for further optimizations (such as partial evaluation).

Example Stan program:

    functions {
      int incr(int x) {
        int y = 1;
        return x + y;
      }
    }
    transformed data {
      int a = 2;
      int b = incr(a);
    }

Program after function inlining (simplified from the output of `--debug-optimized-mir-pretty`):

    prepare_data {
      data int a;
      a = 2;
      data int b;
      data int inline_sym1__;
      data int inline_sym3__;
      inline_sym3__ = 0;
      for(inline_sym4__ in 1:1) {
        int inline_sym2__;
        inline_sym2__ = 1;
        inline_sym3__ = 1;
        inline_sym1__ = (a + inline_sym2__);
        break;
      }
      b = inline_sym1__;
    }


<a id="orgdccffb8"></a>

## DONE Static loop unrolling

<a id="org5d397e8"></a>
Static loop unrolling takes a loop that has a predictable number of iterations `X` and replaces it by writing out the loop body `X` times.
The loop index in each repeat is replaced with the appropriate constant.
This can speed up a program by avoiding the overhead of a loop and providing more opportunities for further optimizations (such as partial evaluation).

Example Stan program:

    transformed data {
      int x = 0;
      for (i in 1:4) {
        x += i;
      }
    }

Program after static loop unrolling (simplified from the output of `--debug-optimized-mir-pretty`):

    prepare_data {
      data int x;
      x = 0;
      x = (x + 1);
      x = (x + 2);
      x = (x + 3);
      x = (x + 4);
    }


<a id="org2a4947e"></a>

## DONE One step loop unrolling

One step loop unrolling is similar to [static loop unrolling](#org5d397e8), but it only 'unrolls' the first iteration of a loop, and can therefore work even when the total number of iterations is not predictable.
This can speed up a program by providing more opportunities for further optimizations such as partial evaluation and lazy code motion.

Example Stan program:

    data {
      int n;
    }
    transformed data {
      int x = 0;
      for (i in 1:n) {
        x += i;
      }
    }

Program after one step static loop unrolling (simplified from the output of `--debug-optimized-mir-pretty`):

    prepare_data {
      data int n = FnReadData__("n")[1];
      int x = 0;
      if((n >= 1)) {
        x = (x + 1);
        for(i in (1 + 1):n) {
          x = (x + i);
        }
      }
    }


<a id="org2036c36"></a>

## DONE Constant propagation

Constant propagation replaces uses of a variable which is known to have a constant value `C` with that constant `C`.
This removes the overhead of looking up the variable, and also makes many other optimizations possible (such as static loop unrolling and partial evaluation).

Example Stan program:

    transformed data {
      int n = 100;
      int a[n];
      for (i in 1:n) {
        a[i] = i;
      }
    }

Program after constant propagation (simplified from the output of `--debug-optimized-mir-pretty`):

    prepare_data {
      data int n = 100;
      data array[int, 100] a;
      for(i in 1:100) {
        a[i] = i;
      }
    }


<a id="org5c810bc"></a>

## DONE Expression propagation

<a id="org115fab8"></a>
Constant propagation replaces uses of a variable which is known to have a constant value `E` with that constant `E`.
This often results in recalculation of the expression, but provides more opportunities for further optimizations such as partial evaluation.
Expression propagation is always followed by [lazy code motion](#org4372649) to avoid unnecessarily recomputing expressions.

Example Stan program:

    data {
      int m;
    }
    transformed data {
      int n = m+1;
      int a[n];
      for (i in 1:n-1) {
        a[i] = i;
      }
    }

Program after expression propagation (simplified from the output of `--debug-optimized-mir-pretty`):

    prepare_data {
      data int m = FnReadData__("m")[1];
      data int n = (m + 1);
      data array[int, (m + 1)] a;
      for(i in 1:((m + 1) - 1)) {
        a[i] = i;
      }
    }


<a id="org76cd4f4"></a>

## DONE Copy propagation

Copy propagation is similar to [expression propagation](#org115fab8), but only propagates variables rather than arbitrary expressions.
This can reduce the complexity of the code for other optimizations such as expression propagation.

Example Stan program:

    model {
      int i = 1;
      int j = i;
      int k = i + j;
    }

Program after copy propagation (simplified from the output of `--debug-optimized-mir-pretty`):

    log_prob {
      int i = 1;
      int j = i;
      int k = (i + i);
    }


<a id="orgdd99c0a"></a>

## DONE Dead code elimination

Dead code is code that does not have any effect on the behavior of the program.
Code is not dead if it affects `target`, the value of any outside-observable variable like transformed parameters or generated quantities, or side effects such as print statements.
Removing dead code can speed up a program by avoiding unnecessary computations.

Example Stan program:

    model {
      int i;
      i = 5;
      for (j in 1:10);
      if (0) {
        print("Dead code");
      } else {
        print("Hi!");
      }
    }

Program after dead code elimination (simplified from the output of `--debug-optimized-mir-pretty`):

    log_prob {
      int i;
      FnPrint__("Hi!");
    }


<a id="org11fafb9"></a>

## DONE Partial evaluation

Partial evaluation searches for expressions that can be replaced with a faster, simpler, more memory efficient, or more numerically stable expression that has the same meaning.

Example Stan program:

    model {
      real a = 1 + 1;
      real b = log(1 - a);
      real c = a + b * 5;
    }

Program after partial evaluation (simplified from the output of `--debug-optimized-mir-pretty`):

    log_prob {
      real a = 2;
      real b = log1m(a);
      real c = fma(b, 5, a);
    }


<a id="orgec8beaf"></a>

## Lazy code motion

<a id="org4372649"></a>
Lazy code motion rearranges the statements and expressions in a program with the goals of:

-   Avoiding computing expressions more than once, and
-   Computing expressions as late as possible (to minimize the strain on the working memory set).

To accomplish these goals, lazy code motion will perform optimizations such as:

-   Moving a repeatedly calculated expression its own variable (also referred to as *common-subexpression elimination*)
-   Moving an expression outside of a loop, if it doesn't need to be in the loop (also referred to as *loop-invariant code motion*)

Lazy code motion can make some programs significantly more efficient by avoiding redundant or early computations.

Example Stan program:

    model {
      real x;
      real y;
      real z;
    
      for (i in 1:10) {
        x = sqrt(10);
        y = sqrt(i);
      }
      z = sqrt(10);
    }

Program after lazy code motion (simplified from the output of `--debug-optimized-mir-pretty`):

    log_prob {
      data real lcm_sym4__;
      data real lcm_sym3__;
      real x;
      real y;
      lcm_sym4__ = sqrt(10);
      real z;
      for(i in 1:10) {
        x = lcm_sym4__;
        y = sqrt(i);
      }
      z = lcm_sym4__;
    }


<a id="org6c7e9be"></a>

## DONE Auto-differentiation level optimization

Stan variables can have two auto-differentiation (AD) *levels*: AD or non-AD.
AD variables carry gradient information with them, which allows Stan to calculate the log-density gradient, but they also have more overhead than non-AD variables.
It is therefore inefficient for a variable to be AD unnecessarily.
AD-level optimization sets every variable to be non-AD unless its gradient is necessary.

Example Stan program:

    data {
      real y;
    }
    model {
      real x = y + 1;
    }

Program after AD-level optimization (simplified from the output of `--debug-optimized-mir-pretty`):

    input_vars {
      real y;
    }
    
    log_prob {
      data real x = (y + 1);
    }

