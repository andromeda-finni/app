/// Which drawing of the pet to show. The art ships one file per mood per fur
/// colour, so the screen never tints or overlays anything — it just picks.
enum PetMood { base, happy, sad, sleep, fully }

const _moodFolder = <PetMood, String>{
  PetMood.base: 'base',
  PetMood.happy: 'happy',
  PetMood.sad: 'sad',
  PetMood.sleep: 'sleep',
  PetMood.fully: 'fully',
};

/// `cosmetic_options.id` (what the backend stores) to the art folder name.
const _furFolder = <String, String>{
  'FUR_GRAY': 'striped',
  'FUR_ORANGE': 'red',
  'FUR_WHITE': 'white',
};

/// Shown before a fur colour has been chosen. It deliberately matches the
/// first (grey) option, so choosing grey never swaps the cat to another pose.
const kBaseCatAsset = 'assets/Cat/Red_collar/base/striped.png';

String catAsset({required String? furOptionId, PetMood mood = PetMood.base}) {
  final fur = _furFolder[furOptionId];
  if (fur == null) return kBaseCatAsset;
  return 'assets/Cat/Red_collar/${_moodFolder[mood]}/$fur.png';
}

// A pet event (illness) takes 45 health off, so "unwell" has to start above
// 55 or the pet would look perfectly fine while an unpaid bill is pending.
const _sadHealth = 60;
const _sadJoy = 20;
const _sleepySatiety = 20;
const _stuffedSatiety = 90;

// A new pet starts at satiety 100 and joy 50, so "stuffed" also asks for a
// cheerful mood — otherwise every pet would be drawn as a food coma from the
// moment it is created, and the pose would stop meaning anything.
const _stuffedJoy = 60;
const _happyJoy = 70;
const _happySatiety = 50;

/// Picks the pet's expression from its stats, worst news first: being ill or
/// miserable shows over being well fed, so a problem is never hidden behind a
/// happy face.
PetMood moodFor({required int satiety, required int joy, required int health}) {
  if (health < _sadHealth || joy <= _sadJoy) return PetMood.sad;
  if (satiety <= _sleepySatiety) return PetMood.sleep;
  if (satiety >= _stuffedSatiety && joy >= _stuffedJoy) return PetMood.fully;
  if (joy >= _happyJoy && satiety >= _happySatiety) return PetMood.happy;
  return PetMood.base;
}
