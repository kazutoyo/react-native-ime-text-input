import { StatusBar } from 'expo-status-bar';
import { TextInput, type TextInputRef } from 'react-native-ime-text-input';
import { useRef, useState } from 'react';
import {
  Button,
  KeyboardAvoidingView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput as RNTextInput,
  View,
} from 'react-native';

/**
 * Verification screen.
 *
 * Rows 1..8 exist so the lower ones are laid out off-screen — that is what made
 * the @expo/ui hosts drift. Content must stay inside its magenta box.
 */
const ROWS = Array.from({ length: 8 }, (_, i) => i + 1);

export default function App() {
  return (
    <KeyboardAvoidingView style={styles.screen} behavior="padding">
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.title}>react-native-ime-text-input</Text>
        <Text style={styles.hint}>
          Type Japanese and compare the underline. Section 1 is React Native&apos;s TextInput
          (expected: no underline). Content must stay inside its magenta box.
        </Text>

        <Section label="1. react-native TextInput — control">
          <RNControl />
        </Section>

        <Section label="2. Controlled (standard useState)">
          <Controlled />
        </Section>

        <Section label="3. Uncontrolled (defaultValue + ref)">
          <Uncontrolled />
        </Section>

        <Section label="4. Controlled, parent refuses every edit">
          <Refusing />
        </Section>

        <Section label="5b. Text attributes (lineHeight / letterSpacing / italic / underline)">
          <Attributed />
        </Section>

        <Section label="5. secureTextEntry / maxLength=5">
          <SecureAndMax />
        </Section>

        {ROWS.map((n) => (
          <Section key={n} label={`drift row ${n}`}>
            <Framed>
              <TextInput style={styles.input} placeholder={`row ${n}`} testID={`drift-${n}`} />
            </Framed>
          </Section>
        ))}
      </ScrollView>

      <ChatComposer />
      <StatusBar style="auto" />
    </KeyboardAvoidingView>
  );
}

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.label}>{label}</Text>
      {children}
    </View>
  );
}

function Framed({ children }: { children: React.ReactNode }) {
  return <View style={styles.frame}>{children}</View>;
}

function RNControl() {
  const [text, setText] = useState('');
  return (
    <Framed>
      <RNTextInput
        style={styles.input}
        value={text}
        onChangeText={setText}
        placeholder="Type here"
        testID="rn-control"
      />
    </Framed>
  );
}

function Controlled() {
  const [text, setText] = useState('');
  return (
    <>
      <Framed>
        <TextInput
          style={styles.input}
          value={text}
          onChangeText={setText}
          placeholder="Type here"
          testID="controlled"
        />
      </Framed>
      <Text style={styles.echo}>value: {JSON.stringify(text)}</Text>
    </>
  );
}

function Uncontrolled() {
  const inputRef = useRef<TextInputRef>(null);
  const [echo, setEcho] = useState('hello');
  return (
    <>
      <Framed>
        <TextInput
          ref={inputRef}
          style={styles.input}
          defaultValue="hello"
          onChangeText={setEcho}
          testID="uncontrolled"
        />
      </Framed>
      <Text style={styles.echo}>value: {JSON.stringify(echo)}</Text>
      <View style={styles.row}>
        <Button title="focus" onPress={() => inputRef.current?.focus()} />
        <Button title="blur" onPress={() => inputRef.current?.blur()} />
        <Button title="clear" onPress={() => inputRef.current?.clear()} />
      </View>
    </>
  );
}

function Refusing() {
  const [attempts, setAttempts] = useState(0);
  return (
    <>
      <Framed>
        <TextInput
          style={styles.input}
          value="locked"
          onChangeText={() => setAttempts((n) => n + 1)}
          testID="refusing"
        />
      </Framed>
      <Text style={styles.echo}>rejected edits: {attempts}</Text>
    </>
  );
}

/** Every attributed-text style at once: the IME underline must still appear. */
function Attributed() {
  const [text, setText] = useState('');
  return (
    <>
      <Framed>
        <TextInput
          style={styles.attributed}
          value={text}
          onChangeText={setText}
          placeholder="Styled"
          testID="attributed"
        />
      </Framed>
      <Text style={styles.echo}>value: {JSON.stringify(text)}</Text>
    </>
  );
}

function SecureAndMax() {
  const [secret, setSecret] = useState('');
  const [short, setShort] = useState('');
  return (
    <>
      <Framed>
        <TextInput
          style={styles.input}
          value={secret}
          onChangeText={setSecret}
          secureTextEntry
          placeholder="Password"
          testID="secure"
        />
      </Framed>
      <Framed>
        <TextInput
          style={styles.input}
          value={short}
          onChangeText={setShort}
          maxLength={5}
          placeholder="5 max"
          testID="max-length"
        />
      </Framed>
      <Text style={styles.echo}>{JSON.stringify(short)}</Text>
    </>
  );
}

/**
 * The chat composer. No height state and no `onContentSizeChange`: the native
 * view publishes its content size as Fabric state, so Yoga grows the field on
 * its own and `maxHeight` caps it — past that the UITextView scrolls inside.
 */
function ChatComposer() {
  const [text, setText] = useState('');

  return (
    <View style={styles.composer}>
      <TextInput
        style={styles.composerInput}
        value={text}
        onChangeText={setText}
        multiline
        placeholder="Message"
        testID="composer"
      />
      <View style={styles.composerBar}>
        <Text style={styles.echo}>{text.length} chars</Text>
        <Button title="send" onPress={() => setText('')} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { backgroundColor: '#f2f2f7', flex: 1 },
  content: { gap: 16, padding: 16, paddingTop: 72 },
  title: { fontSize: 20, fontWeight: '700' },
  hint: { color: '#3c3c43', fontSize: 12, lineHeight: 16 },
  section: { gap: 4 },
  label: { color: '#3c3c43', fontSize: 12, fontWeight: '600' },
  row: { alignItems: 'center', flexDirection: 'row', gap: 8 },
  echo: { color: '#8e8e93', fontSize: 11 },
  frame: { borderColor: '#ff00ff', borderWidth: 1 },
  input: {
    backgroundColor: '#ffffff',
    color: '#000000',
    fontSize: 17,
    height: 38,
    paddingHorizontal: 10,
  },
  attributed: {
    backgroundColor: '#ffffff',
    color: '#1c1c1e',
    fontSize: 17,
    fontStyle: 'italic',
    height: 44,
    letterSpacing: 1.5,
    lineHeight: 26,
    paddingHorizontal: 10,
    textDecorationLine: 'underline',
  },
  composer: {
    backgroundColor: '#ffffff',
    borderColor: '#c7c7cc',
    borderTopWidth: 1,
    gap: 6,
    padding: 12,
  },
  composerInput: { color: '#000000', fontSize: 17, maxHeight: 110, minHeight: 24 },
  composerBar: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between' },
});
