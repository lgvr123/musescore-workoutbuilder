# Scale Workout Builder plugin for MuseScore 3.x
*Scale Workout Builder plugin for MuseScore 3.x* is a plugin for MuseScore 3.0 for the creation of exercises and workouts scores for practising your playing skills and knowledge of scales, improvisation patterns, ...

## New features in 2.3.0
* In Grid mode, build patterns in the notes defined by the current chord.<br/>E.g. This mode will loop among C,Eb,G,A,Bb for a "Cm6" chord.
* In Grid mode, specify the key signature to use by prefixing it to the pattern (°).<br> E.g. "(bbb)C-7;F-7;D07;G7b9;C-7;Eb-7;Ab7;Dbt7;D07;G7b9;C-7;D07" (from Joe Hendersion's Blue Bossa)
* In Grid mode, use "|" to mark line breaks between Chords.<br/>E.g. "Bb7;Eb7;Bb7;Eb7|Eb7;Eb7;Bb7;Bb7|C-7;F7;Bb7;Bb7" (from Sonny Rollins' Tenor Madness)

* New "Bass instrument"(°°)
* Store the last used settings
* Better handling of Aug, Sus2, Sus4 chords

(°) Due to limitations in the MuseScore API, the plugin is not able to add the key signature. The user must add it manually. However the plugin will use it in order to choose correclty among flats and sharps when building the patterns. 
(°°) Due to limitations in the MuseScore API, the plugin is not able to add the F-clef. The user must add it manually. However, the patterns are transposed accordingly to a F-clef. 

## Features
* Choose workout type between *Scale mode* or *Grid mode*,
* Select the instrument transposition (Concert Pitch, Bb, Bass, ...),
* Define freely up-to 8 patterns of up-to 12 steps each,
* Loop them across the diatonic scale, or by triads,
* Repeat the patterns over different roots (*Scale mode*),
* Extract a a grid of chords from a score (*Grid mode*),
* Export as a MuseScore score.

## Download and Install ##
Download the [last stable version](https://github.com/lgvr123/musescore-workoutbuilder/releases).
For installation see [Plugins](https://musescore.org/en/handbook/3/plugins).

## User manual
Refer to the [PDF instruction file](user_manual.pdf). (NOT UPDATED FOR v2.3.0)


## Credits
Some icons made by [freepik](https://www.flaticon.com/authors/freepik) from [www.flaticon.com](https://www.flaticon.com/)

## Support ##
[<img src="/support/Button-Tipeee.png" alt="Support me on Tipee" height="80"/>](https://fr.tipeee.com/parkingb)

## IMPORTANT
NO WARRANTY THE PROGRAM IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU. SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW THE AUTHOR WILL BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS), EVEN IF THE AUTHOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
–
