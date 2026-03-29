import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import Clutter from 'gi://Clutter';
import Cogl from 'gi://Cogl';

const AMBER_TINT = [1.0, 0.78, 0.18, 1.0];
const EFFECT_PREFIX = 'amber-monochrome';

function makeAmberTint() {
  const tint = new Cogl.Color();
  tint.init_from_4f(...AMBER_TINT);
  return tint;
}

function buildEffects() {
  const desaturate = new Clutter.DesaturateEffect({factor: 1.0});
  const colorize = new Clutter.ColorizeEffect();
  colorize.set_tint(makeAmberTint());

  const contrast = new Clutter.BrightnessContrastEffect();
  contrast.set_brightness_full(-0.05, -0.1, -0.95);
  contrast.set_contrast_full(1.0, 0.72, -1.0);

  return [
    [ "desaturate", desaturate ],
    [ "colorize", colorize ],
    [ "contrast", contrast ],
  ];
}

export default class AmberMonochromeExtension extends Extension {
  enable() {
    const target = global.stage ?? global.window_group ?? Main.layoutManager.uiGroup;
    this._targets = target ? [target] : [];

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
      actor.remove_effect_by_name(`${EFFECT_PREFIX}-colorize`);
      actor.remove_effect_by_name(`${EFFECT_PREFIX}-contrast`);
    }

    this._targets = null;
  }
}
