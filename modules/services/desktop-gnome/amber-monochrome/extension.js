import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import Clutter from 'gi://Clutter';
const EFFECT_PREFIX = 'amber-monochrome';

function buildEffects() {
  const desaturate = new Clutter.DesaturateEffect({factor: 1.0});

  const contrast = new Clutter.BrightnessContrastEffect();
  contrast.set_brightness_full(0.32, 0.06, -1.0);
  contrast.set_contrast_full(1.0, 0.45, -1.0);

  return [
    [ "desaturate", desaturate ],
    [ "contrast", contrast ],
  ];
}

export default class AmberMonochromeExtension extends Extension {
  enable() {
    this._targets = [
      global.window_group,
      Main.layoutManager.uiGroup,
    ].filter((actor, index, actors) => actor && actors.indexOf(actor) === index);

    for (const actor of this._targets) {
      for (const [suffix, effect] of buildEffects()) {
        actor.add_effect_with_name(`${EFFECT_PREFIX}-${suffix}`, effect);
      }
    }
  }

  disable() {
    if (!this._targets) {
      return;
    }

    for (const actor of this._targets) {
      actor.remove_effect_by_name(`${EFFECT_PREFIX}-desaturate`);
      actor.remove_effect_by_name(`${EFFECT_PREFIX}-contrast`);
    }

    this._targets = null;
  }
}
