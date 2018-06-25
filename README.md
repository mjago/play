# Simple Command-line Audio Player with VU-meter in Crystal.

Depends on `libao` and `ffmpeg`

Tested on `mp3`, `flac`, and `m4a` formats

## Installation

```sh
shards install
shards build
chmod +x bin/play
sudo cp bin/play /usr/bin/play
```
## Usage

```sh
play track1 [track2 track3]
```
