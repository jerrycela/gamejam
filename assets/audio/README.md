# Audio assets

Procedurally synthesized with numpy (script kept in the commit that added
them). Not recorded, not sampled from any library — there is no licence to
carry and no attribution to preserve.

Chosen over recorded samples deliberately: these are short UI sounds where
exact length, level and decay matter more than timbral realism, and a
generated waveform can be regenerated and retuned rather than re-sourced.

| file | ms | role |
|---|---|---|
| `sfx_card_deal.wav` | 90 | one card landing — filtered noise burst, paper rather than hiss |
| `sfx_card_flip.wav` | 130 | hole card turning — two-stage: lift, then slap |
| `sfx_button.wav` | 55 | any button press |
| `sfx_chip.wav` | 120 | chip count changing — inharmonic partials, metallic |
| `sfx_win.wav` | 620 | player wins — rising major arpeggio C5-E5-G5-C6 |
| `sfx_blackjack.wav` | 950 | natural blackjack — higher, longer, with a shimmer tail; must read as clearly bigger than a plain win |
| `sfx_lose.wav` | 500 | player loses — falling minor third, soft |
| `sfx_bust.wav` | 420 | player busts — descending buzz, negative but not harsh |
| `sfx_push.wav` | 300 | tie — single neutral tone, deliberately the least eventful |

Every file was verified after generation for peak level, RMS, DC offset and
dominant frequency. Two defects were found and fixed that way rather than by
listening: the button was noticeably quieter than everything else, and the
flip had a DC offset that would have made it sound dull through a speaker.

Levels are intentionally uneven — `sfx_push` is quiet because a tie should
feel like the least eventful outcome, and `sfx_blackjack` is the loudest
because it is the rarest and best one.
