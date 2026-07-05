import React from 'react';
import {
  KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView, StyleSheet,
  Text, TextInput, View,
} from 'react-native';
import { colors } from './config';
import { statusOf } from './types';

const AV_COLORS: [string, string][] = [
  ['#fdeef2', '#c74564'], ['#eaf1f8', '#4a7fb5'], ['#e7f5ee', '#2f8a63'],
  ['#fdf3e2', '#ad7418'], ['#f1eafa', '#7a5cbb'], ['#e6f4f4', '#357f7f'],
];

export function Avatar({ name }: { name: string }) {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  const [bg, fg] = AV_COLORS[h % AV_COLORS.length];
  return (
    <View style={[st.avatar, { backgroundColor: bg }]}>
      <Text style={{ color: fg, fontWeight: '700', fontSize: 17 }}>
        {(name || '?').slice(0, 1)}
      </Text>
    </View>
  );
}

export function StatusBadge({ status }: { status: string }) {
  const s = statusOf(status);
  return (
    <View style={[st.badge, { backgroundColor: s.soft }]}>
      <Text style={{ color: s.color, fontSize: 12, fontWeight: '700' }}>{s.label}</Text>
    </View>
  );
}

export function Stars({ n, size = 14 }: { n: number; size?: number }) {
  if (!n) return null;
  return (
    <Text style={{ color: colors.gold, fontSize: size }}>
      {'★'.repeat(n) + '☆'.repeat(5 - n)}
    </Text>
  );
}

export function Card({ children, style }: { children: React.ReactNode; style?: object }) {
  return <View style={[st.card, style]}>{children}</View>;
}

export function SectionTitle({ children, right }: { children: React.ReactNode; right?: React.ReactNode }) {
  return (
    <View style={st.secTitle}>
      <Text style={st.secTitleText}>{children}</Text>
      <View style={{ flex: 1 }} />
      {right}
    </View>
  );
}

export function Chip({ label, on, color, onPress }: {
  label: string; on: boolean; color?: string; onPress: () => void;
}) {
  const c = color ?? colors.accentDark;
  return (
    <Pressable
      onPress={onPress}
      style={[st.chip, on && { backgroundColor: c + '22', borderColor: c }]}>
      <Text style={[st.chipText, on && { color: c }]}>{label}</Text>
    </Pressable>
  );
}

export function PrimaryButton({ label, onPress, danger }: {
  label: string; onPress: () => void; danger?: boolean;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[st.btn, { backgroundColor: danger ? colors.danger : colors.accent }]}>
      <Text style={st.btnText}>{label}</Text>
    </Pressable>
  );
}

export function SubButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={[st.btn, { backgroundColor: colors.graySoft }]}>
      <Text style={[st.btnText, { color: colors.text }]}>{label}</Text>
    </Pressable>
  );
}

export function Field({ label, value, onChange, placeholder, multiline, keyboardType }: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  multiline?: boolean;
  keyboardType?: 'default' | 'number-pad';
}) {
  return (
    <View style={{ marginBottom: 12 }}>
      <Text style={st.fieldLabel}>{label}</Text>
      <TextInput
        style={[st.input, multiline && { minHeight: 68, textAlignVertical: 'top' }]}
        value={value}
        onChangeText={onChange}
        placeholder={placeholder}
        placeholderTextColor="#b9a9b0"
        multiline={multiline}
        keyboardType={keyboardType ?? 'default'}
      />
    </View>
  );
}

/** 下から出るシート */
export function Sheet({ visible, onClose, title, children }: {
  visible: boolean; onClose: () => void; title: string; children: React.ReactNode;
}) {
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <Pressable style={st.overlay} onPress={onClose}>
          <Pressable style={st.sheet} onPress={() => {}}>
            <View style={st.sheetHead}>
              <Text style={st.sheetTitle}>{title}</Text>
              <Pressable onPress={onClose} hitSlop={10}>
                <Text style={{ color: colors.sub, fontSize: 15 }}>閉じる</Text>
              </Pressable>
            </View>
            <ScrollView keyboardShouldPersistTaps="handled">{children}</ScrollView>
          </Pressable>
        </Pressable>
      </KeyboardAvoidingView>
    </Modal>
  );
}

export const st = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.bg },
  avatar: {
    width: 44, height: 44, borderRadius: 22,
    alignItems: 'center', justifyContent: 'center',
  },
  badge: { paddingHorizontal: 10, paddingVertical: 3, borderRadius: 999 },
  card: {
    backgroundColor: colors.card, borderRadius: 14, padding: 14,
    marginBottom: 10, borderWidth: 1, borderColor: colors.line,
  },
  secTitle: { flexDirection: 'row', alignItems: 'center', marginTop: 16, marginBottom: 8 },
  secTitleText: { fontSize: 14, fontWeight: '700', color: colors.sub },
  chip: {
    paddingHorizontal: 14, paddingVertical: 6, borderRadius: 999,
    backgroundColor: colors.graySoft, borderWidth: 1, borderColor: 'transparent',
    marginRight: 8,
  },
  chipText: { fontSize: 13.5, fontWeight: '700', color: colors.sub },
  btn: {
    borderRadius: 12, paddingVertical: 14, alignItems: 'center', marginTop: 8,
  },
  btnText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  fieldLabel: { fontSize: 13.5, fontWeight: '700', color: colors.sub, marginBottom: 5 },
  input: {
    backgroundColor: colors.card, borderWidth: 1, borderColor: colors.line,
    borderRadius: 10, paddingHorizontal: 12, paddingVertical: 10, fontSize: 16,
    color: colors.text,
  },
  overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.45)', justifyContent: 'flex-end' },
  sheet: {
    backgroundColor: colors.bg, borderTopLeftRadius: 18, borderTopRightRadius: 18,
    padding: 18, maxHeight: '92%',
  },
  sheetHead: { flexDirection: 'row', alignItems: 'center', marginBottom: 14 },
  sheetTitle: { fontSize: 16, fontWeight: '700', flex: 1, color: colors.text },
  rowText: { fontSize: 15.5, color: colors.text },
  subText: { fontSize: 13.5, color: colors.sub },
});
