package com.kazutoyo.imetextinput

import android.content.Context
import android.view.inputmethod.BaseInputConnection
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.uimanager.UIManagerHelper

/**
 * Backs `commitComposition()` on Android.
 *
 * React Native replaces a TextInput's text with `SpannableStringBuilder#replace`
 * and then puts back every exclusive span whose characters are unchanged
 * (`ReactEditText#manageSpans`) — the IME's composing span included. So when a
 * value is set while the user is composing, the conversion survives the update
 * and only the caret moves, out of the composing region. IMEs disagree on what
 * that means: Gboard keeps composing (the next keystroke lands inside the old
 * region), others treat it as a cancelled conversion and delete the composed
 * text. Neither is what the app asked for.
 *
 * Ending the composition first makes the update land on plain text: drop the
 * composing span, then restart input so the IME discards its own composing
 * state too. The text itself is left exactly as it is, the same as tapping
 * elsewhere in the field would leave it.
 */
class ImeTextInputModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

  override fun getName() = NAME

  @ReactMethod
  fun commitComposition(reactTag: Double) {
    val tag = reactTag.toInt()
    // ponytail: posted straight to the UI thread rather than ordered with mount
    // items. It lands before the next frame's mount in practice; if a value
    // update ever wins, restartInput still invalidates the IME's old
    // connection, so no edit based on the stale composition reaches the field.
    UiThreadUtil.runOnUiThread {
      val view =
          UIManagerHelper.getUIManagerForReactTag(reactApplicationContext, tag)?.resolveView(tag)
              as? EditText ?: return@runOnUiThread
      val text = view.text ?: return@runOnUiThread
      if (BaseInputConnection.getComposingSpanStart(text) == -1) return@runOnUiThread

      BaseInputConnection.removeComposingSpans(text)
      val imm = view.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
      imm.restartInput(view)
    }
  }

  companion object {
    const val NAME = "RNImeTextInputModule"
  }
}
