---
title: Succeeding at Lottery
date: 2016-09-01
toc: yes
code: yes
mathjax: yes
references: bib/succeeding-at-lottery.bib
link-citations: true
---

## Introduction

This article completely describes [*The Lottery Problem*](#the-lottery-problem),
displays some convenient results from the mathematical research, goes through
several algorithmic approaches for solving the problem and displays some lottery
numbers, pictures and tickets.

Programming language used in the code snippets is Haskell but when the lottery
numbers get large C++ is used instead. All needed functions can be found in a
[git repository on Github](https://github.com/vjeranc/lottery). Haskell was
chosen due to a lovely
[REPL](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop).

## The Lottery Problem

Most of my life I was pretty sure that lottery is a game of luck, where having
an advantage meant that there's something wrong with the the method of
extracting the numbers.

My stance was a bit shaken by encountering a task posed by my professor during
my first year at university. It can be stated as follows:

> Given a lottery $L(n, k, r)$, where $n$ represents the count of possible
> numbers and $k$ the count of numbers that can be on a ticket, what is the
> minimum number of tickets that will guarantee that at least $r$ numbers will
> be matched after winning ticket is drawn?

We were told nothing about the task, other than that it is an open problem.
Concrete numbers were also given -- $(n, k, r) = (24, 5, 2)$ and $r=3$ if time
allowed.

Task asks us to find a function
$L : \mathbb{N}\times \mathbb{N}\times \mathbb{N} \rightarrow \mathbb{N}$. It
might be easier to figure out an algorithm that discovers tickets instead of a
symbolic formula, or at least that's what we would like -- to know which
tickets to buy, and become financially independent.

It might not be clear that difficulty of the task varies depending on the
$(n, k, r)$ parameters, or that the task is at all difficult. For example, if
$(n, k, r) = (15, 5, 5)$ then buying all of the tickets will guarantee that $5$
numbers are matched, buying one ticket less makes the desired outcome
uncertain. It's less clear what $L(24, 5, 2)$ is, we could buy tickets that
have all the needed pairs of numbers that we need to match but finding the set
of tickets with minimal cardinality isn't as straightforward as it is for the
$L(n, k, k)$ case.

## Producing all of the tickets

If we just want to try something out one of the first things that comes to mind
is to play around with tickets (or maybe you still want to play with the numbers
-- then go on, play). Code for producing all of the tickets of a given set of
numbers is given below.

```haskell
import Control.Monad (filterM)
-- subsets [1,2,3] 2 == [[1,2],[1,3],[2,3]]
subsets xs k = filter ((==k) . length) $ filterM (\_ -> [True, False]) xs
```

It's a nice example of beautiful Haskell magic but it's not as efficient as one
would like. Especially since `filterM` produces all of the possible subsets
which are then filtered to produce those of the wanted size. The `subsets`
function could be improved but it still wouldn't be efficient enough. Integer
representation of a ticket would be much more space and time efficient. For the
numbers from the introduction only 24 bits are needed and those $k$ bits would
be set indicating which numbers the ticket has.

Efficient enumeration of all the tickets is possible and the needed function is
present in the book that I wholeheartedly recommend -- [Hacker's
Delight](http://www.hackersdelight.org/).[^1] E.g. starting with a ticket
`[1,2,3] == 0b0111` we'd like to get the next ticket `[1,2,4] == 0b1011`.
Fortunately, the `snoob` function below gives us exactly what we want and allows
us to iterate over all $k$-bit tickets, starting from `[1,2,3]` and finishing at
`[n-2,n-1,n]`. Formally, it calculates the next smallest number of same
bit-count as given $x$.

```haskell
import Data.Bits
-- snoob 0x07 == 0x0B (which is 0b1011)
snoob x =
  let smallest = x .&. (-x)
      ripple   = x + smallest
      ones     = x `xor` ripple
      ones2    = (ones `shiftR` 2) `div` smallest
  in ripple .|. ones2
```

## The greedy approach

Now that we can [generate all of the tickets](#producing-all-of-the-tickets)
it's easy to play around with sets of tickets and find some sets that will
guarantee the desired outcome.

It would be nice to know the guarantees of this algorithm. What kind of
solutions are found? How far or close is the discovered set to the one of
minimal cardinality? Fortunately, this algorithm has mathematical guarantees.

## Numbers in the lottery problem

Lottery problem $L(n,k,r)$ has a bunch of numbers:

1. number of all possible tickets $\binom{n}{k}$,
2. number of tickets that a particular one covers $\sum_{i=r}^{k} \binom{k}{i}
\binom{n-k}{k-i}$,
3. number of tickets that two tickets cover -- this one is harder to symbolize
because the number depends on the particular ticket pair,
4. the very optimistic lower bound
$\Bigg\lceil\frac{\binom{n}{k}}{\sum_{i=r}^{k}
  \binom{k}{i} \binom{n-k}{k-i}}\Bigg\rceil \leq L(n,k,r)$,
5. and others.

### $L(n,k,r)$ as a covering problem

#### Combinatorial design theory

### *Easy* numbers

### *Hard* numbers

See [@furedi1996lottery; @colbourn2006handbook; @burger2007towards;
@etzion1995bounds]. And also [@vazirani2013approximation, chapter 1, page 33].

[@vazirani2013approximation, pp. 33-35, 38-39 and *passim*].

See [@furedi1996lottery; @colbourn2006handbook; @burger2007towards].

#### Inclusion-Exclusion principle


![Fig 1. This is the caption that is loving and kind. Brutal and honest it
seems to be but I cannot find its pipe. Pipe is the dream, pipe is the
might.](/images/haskell-logo.png)

[^1]: Hacker's Delight by Warren, Chapter 2. Basics - A Novel Application
[^2]: <https://hackage.haskell.org/package/FixedPoint-simple-0.6.1>
