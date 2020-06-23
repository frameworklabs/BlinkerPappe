# BlinkerPappe

A simple demo for the Pappe embedded interpreted syncrhronous Swift DSL.

## Overview

This demo replicates the [Blech blinker demo](https://github.com/frameworklabs/blinker) for the [Pappe Swift DSL](https://github.com/frameworklabs/Pappe).

It shows how the synchronous programming approach simplifies the control logic even in a high level language like Swift and on a platform like MacOS with its many frameworks.

The program uses the SpriteKit framework which alternates at 60Hz between updating the scene state via a user provided callback and presenting the new sceen state automatically. This callback approach normally tears the imperative control flow apart forcing you to use a state-machine instead which get hard to follow quickly. The imperative synchronous programming paradigm as proposed by languages like [Blech](https://blech-lang.org) helps you to stay in control instead.

## How to build

Open the "BlinkerPappe.xcodeproj" project file with Xcode >= 11.5 - it should automatically resolve the needed Pappe Package dependency.

## Caveats

The Pappe DSL is more of a proof of concept. It has many shortcommings like:

* No causality checking.
* Interpreted instead of compiled.
* Untyped and unchecked variables.
* The way Swift functionBuilders are used requires always at least 2 statements - hence many ugly `nop` statements.
* FunctionBuilder support for `if` statements not used.
* Poor Test coverage.
