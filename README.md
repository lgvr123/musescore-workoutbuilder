# Scale Workout Builder plugin for MuseScore 3.x
*Scale Workout Builder plugin for MuseScore 3.x* is a plugin for MuseScore 3.0 for the creation of exercises and workouts scores for practising your playing skills and knowledge of scales, improvisation patterns, ...
<p align="center"><img src="/workoutbuilder/logo.png" Alt="logo" width="300" /></p>

![Scale Workout Builder plugin](/demo/demo scale workout builder.gif)

## New features in 2.4.1
* [Improvment] Better titles in the new *One score by root* mode
* [Bug] [Issue#2](https://github.com/lgvr123/musescore-workoutbuilder/issues/2) The plugin did not show up on some Linux configurations

## New features in 2.4.0
* [New] Add steps duration (quarter, dotted, ...)
* [New] Option to produce one score by root note, allowing for producing exercise sheets for multiple roots at once. 
* [Improvement] Chord naming, chords extraction from a current score (grid mode)

## Features
* Choose workout type between *Scale mode* or *Grid mode*,
* Select the instrument transposition (Concert Pitch, Bb, Bass, ...),
* Define freely up-to 8 patterns of up-to 12 steps each,
* Loop them across the diatonic scale, or by triads,
* Repeat the patterns over different roots (*Scale mode*),
* Extract a a grid of chords from a score (*Grid mode*),
* Export as one of multiple MuseScore scores.
* Define steps duration

## Download and Install ##
Download the [last stable version](https://github.com/lgvr123/musescore-workoutbuilder/releases).
For installation see [Plugins](https://musescore.org/en/handbook/3/plugins).
### Remark
The `workoutbuilder/ ` folder must be unzipped **as such** in your plugin folder (so leading to ´.../plugins/workoutbuilder/...´) . <br/>
If you had a previous version installed, please delete the previous `workoutbuilder.qml` file to avoid conflicts.

## Support of MS4.0
**NOT SUPPORTED**

MuseScore 4.0 support for plugin is minimal. Many functions like creation of scores, reading of scores through the API are not implemented yet.
Therefore, this plugin does not work under MuseScore 4.0.

## User manual
Refer to the [PDF instruction file](user_manual.pdf). (NOT UPDATED FOR v2.3.0)

## Known issues
* Due to limitations in the MuseScore API, the plugin is not able to add the key signature. The user must add it manually. However the plugin will use it in order to choose correclty among flats and sharps when building the patterns. 
* Due to limitations in the MuseScore API, the plugin is not able to add the F-clef. The user must add it manually. However, the patterns are transposed accordingly to a F-clef. 
* Not working under MuseScore 4.0 for now (not even appearing in MuseScore 4 plugins panel).


## Credits
Some icons made by [freepik](https://www.flaticon.com/authors/freepik) from [www.flaticon.com](https://www.flaticon.com/)

## Sponsorship ##
If you appreciate my plugins, you can support and sponsor their development on the following platforms:
[<img src="/support/Button-Tipeee.png" alt="Support me on Tipee" height="50"/>](https://www.tipeee.com/parkingb) 
[<img src="/support/paypal.jpg" alt="Support me on Paypal" height="55"/>](https://www.paypal.me/LaurentvanRoy) 
[<img src="/support/patreon.png" alt="Support me on Patreon" height="25"/>](https://patreon.com/parkingb)

And also check my **[Zploger application](https://www.parkingb.be/zploger)**, a tool for managing a library of scores, with extended MuseScore support.

## IMPORTANT
NO WARRANTY THE PROGRAM IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU. SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW THE AUTHOR WILL BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS), EVEN IF THE AUTHOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
–
