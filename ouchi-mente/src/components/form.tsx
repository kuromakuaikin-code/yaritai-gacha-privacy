import React, { useState } from "react";
import DateTimePicker from "@react-native-community/datetimepicker";
import {
  Modal,
  Platform,
  Pressable,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
  type KeyboardTypeOptions,
} from "react-native";
import { formatDateJa, parseDateString, toDateString } from "@/domain/schedule";
import { colors, fontSize, radius, spacing } from "@/theme";

export function FormSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      <View style={styles.sectionBody}>{children}</View>
    </View>
  );
}

export function FieldLabel({
  label,
  required,
}: {
  label: string;
  required?: boolean;
}) {
  return (
    <Text style={styles.fieldLabel}>
      {label}
      {required ? <Text style={styles.required}>（必須）</Text> : null}
    </Text>
  );
}

export function FieldError({ message }: { message?: string }) {
  if (!message) return null;
  return <Text style={styles.fieldError}>{message}</Text>;
}

export function TextField({
  label,
  required,
  value,
  onChangeText,
  placeholder,
  error,
  multiline,
  keyboardType,
}: {
  label: string;
  required?: boolean;
  value: string;
  onChangeText: (text: string) => void;
  placeholder?: string;
  error?: string;
  multiline?: boolean;
  keyboardType?: KeyboardTypeOptions;
}) {
  return (
    <View style={styles.field}>
      <FieldLabel label={label} required={required} />
      <TextInput
        style={[
          styles.input,
          multiline && styles.inputMultiline,
          error != null && styles.inputError,
        ]}
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor={colors.textMuted}
        multiline={multiline}
        keyboardType={keyboardType}
      />
      <FieldError message={error} />
    </View>
  );
}

/** 候補から1つ選ぶチップ型セレクタ。自由入力と組み合わせて使うこともある */
export function ChipSelect<T extends string | number>({
  label,
  required,
  options,
  value,
  onChange,
  error,
}: {
  label?: string;
  required?: boolean;
  options: { value: T; label: string }[];
  value: T | undefined;
  onChange: (value: T) => void;
  error?: string;
}) {
  return (
    <View style={styles.field}>
      {label ? <FieldLabel label={label} required={required} /> : null}
      <View style={styles.chipRow}>
        {options.map((option) => {
          const selected = option.value === value;
          return (
            <Pressable
              key={`${option.value}`}
              accessibilityRole="button"
              accessibilityState={{ selected }}
              onPress={() => onChange(option.value)}
              style={[styles.chip, selected && styles.chipSelected]}
            >
              <Text
                style={[styles.chipText, selected && styles.chipTextSelected]}
              >
                {selected ? "✓ " : ""}
                {option.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
      <FieldError message={error} />
    </View>
  );
}

/**
 * 日付入力。タップでOSのカレンダーピッカーを開く。
 * value は YYYY-MM-DD。
 */
export function DateField({
  label,
  required,
  value,
  onChange,
  placeholder = "日付を選択",
  error,
  clearable,
}: {
  label: string;
  required?: boolean;
  value: string | undefined;
  onChange: (value: string | undefined) => void;
  placeholder?: string;
  error?: string;
  clearable?: boolean;
}) {
  const [pickerVisible, setPickerVisible] = useState(false);

  const handleChange = (date: Date | undefined) => {
    if (Platform.OS === "android") setPickerVisible(false);
    if (date) onChange(toDateString(date));
  };

  return (
    <View style={styles.field}>
      <FieldLabel label={label} required={required} />
      <View style={styles.dateRow}>
        <Pressable
          accessibilityRole="button"
          style={[styles.input, styles.dateInput, error != null && styles.inputError]}
          onPress={() => setPickerVisible(true)}
        >
          <Text style={value ? styles.dateText : styles.datePlaceholder}>
            {value ? formatDateJa(value) : placeholder}
          </Text>
        </Pressable>
        {clearable && value ? (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="日付をクリア"
            onPress={() => onChange(undefined)}
            style={styles.clearButton}
          >
            <Text style={styles.clearButtonText}>クリア</Text>
          </Pressable>
        ) : null}
      </View>
      <FieldError message={error} />
      {pickerVisible && Platform.OS === "android" ? (
        <DateTimePicker
          value={value ? parseDateString(value) : new Date()}
          mode="date"
          display="calendar"
          onChange={(_, date) => handleChange(date)}
        />
      ) : null}
      {Platform.OS === "ios" ? (
        <Modal
          visible={pickerVisible}
          transparent
          animationType="fade"
          onRequestClose={() => setPickerVisible(false)}
        >
          <Pressable
            style={styles.modalBackdrop}
            onPress={() => setPickerVisible(false)}
          >
            <Pressable style={styles.modalSheet} onPress={() => {}}>
              <DateTimePicker
                value={value ? parseDateString(value) : new Date()}
                mode="date"
                display="inline"
                locale="ja-JP"
                onChange={(_, date) => handleChange(date)}
              />
              <Pressable
                accessibilityRole="button"
                style={styles.modalDone}
                onPress={() => setPickerVisible(false)}
              >
                <Text style={styles.modalDoneText}>決定</Text>
              </Pressable>
            </Pressable>
          </Pressable>
        </Modal>
      ) : null}
    </View>
  );
}

export function SwitchRow({
  label,
  value,
  onChange,
}: {
  label: string;
  value: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <View style={styles.switchRow}>
      <Text style={styles.switchLabel}>{label}</Text>
      <Switch
        value={value}
        onValueChange={onChange}
        trackColor={{ true: colors.primary }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  section: {
    marginBottom: spacing.xl,
  },
  sectionTitle: {
    fontSize: fontSize.md,
    fontWeight: "700",
    color: colors.textSecondary,
    marginBottom: spacing.sm,
  },
  sectionBody: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.lg,
  },
  field: {
    marginBottom: spacing.md,
  },
  fieldLabel: {
    fontSize: fontSize.md,
    color: colors.text,
    fontWeight: "600",
    marginBottom: spacing.xs,
  },
  required: {
    color: colors.overdue,
    fontSize: fontSize.sm,
    fontWeight: "400",
  },
  fieldError: {
    color: colors.danger,
    fontSize: fontSize.sm,
    marginTop: spacing.xs,
  },
  input: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    fontSize: fontSize.md,
    color: colors.text,
    backgroundColor: colors.background,
    minHeight: 46,
  },
  inputMultiline: {
    minHeight: 90,
    textAlignVertical: "top",
  },
  inputError: {
    borderColor: colors.danger,
  },
  chipRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm,
  },
  chip: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.pill,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    backgroundColor: colors.background,
  },
  chipSelected: {
    borderColor: colors.primary,
    backgroundColor: colors.primarySoft,
  },
  chipText: {
    fontSize: fontSize.md,
    color: colors.textSecondary,
  },
  chipTextSelected: {
    color: colors.primary,
    fontWeight: "600",
  },
  dateRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
  },
  dateInput: {
    flex: 1,
    justifyContent: "center",
  },
  dateText: {
    fontSize: fontSize.md,
    color: colors.text,
  },
  datePlaceholder: {
    fontSize: fontSize.md,
    color: colors.textMuted,
  },
  clearButton: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  clearButtonText: {
    color: colors.textSecondary,
    fontSize: fontSize.md,
  },
  switchRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: spacing.sm,
  },
  switchLabel: {
    fontSize: fontSize.md,
    color: colors.text,
    flex: 1,
    marginRight: spacing.md,
  },
  modalBackdrop: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.4)",
    justifyContent: "center",
    padding: spacing.xl,
  },
  modalSheet: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    padding: spacing.lg,
  },
  modalDone: {
    alignItems: "center",
    paddingVertical: spacing.md,
  },
  modalDoneText: {
    color: colors.primary,
    fontSize: fontSize.lg,
    fontWeight: "600",
  },
});
