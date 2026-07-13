import React, { useEffect, useRef, useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { Controller, useForm } from "react-hook-form";
import {
  Image,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { z } from "zod";
import {
  ChipSelect,
  DateField,
  FormSection,
  SwitchRow,
  TextField,
} from "./form";
import { AppButton, NoteText } from "./ui";
import {
  CATEGORY_LABELS,
  GUIDANCE_NOTE,
  INTERVAL_UNIT_LABELS,
  LOCATION_SUGGESTIONS,
  NOTIFICATION_TIMING_OPTIONS,
  SCHEDULE_TYPE_LABELS,
  TASK_TYPE_LABELS,
} from "@/domain/labels";
import {
  addInterval,
  formatDateJa,
  isValidDateString,
  todayString,
} from "@/domain/schedule";
import type {
  IntervalUnit,
  MaintenanceCategory,
  MaintenanceTaskType,
  NewMaintenanceItem,
  ScheduleType,
} from "@/domain/types";
import {
  deleteStoredImageAsync,
  pickAndStoreImageAsync,
  resolveImageUri,
} from "@/media/images";
import { colors, fontSize, radius, spacing } from "@/theme";

const formSchema = z
  .object({
    name: z.string().trim().min(1, "項目名を入力してください"),
    category: z.custom<MaintenanceCategory>(
      (v) => typeof v === "string" && v.length > 0,
      "カテゴリーを選択してください",
    ),
    taskType: z.custom<MaintenanceTaskType>(
      (v) => typeof v === "string" && v.length > 0,
      "作業種別を選択してください",
    ),
    location: z.string(),
    /** 新規登録時のみ使用。前回実施日または開始日 */
    baseDate: z.string().optional(),
    /** 編集時のみ使用。次回予定日の直接変更 */
    nextDueDateOverride: z.string().optional(),
    scheduleType: z.custom<ScheduleType>(
      (v) => v === "interval" || v === "fixedDate" || v === "none",
      "次回目安の設定方法を選択してください",
    ),
    intervalValue: z.string(),
    intervalUnit: z.custom<IntervalUnit>(
      (v) => v === "day" || v === "week" || v === "month" || v === "year",
    ),
    fixedDate: z.string().optional(),
    notificationEnabled: z.boolean(),
    notificationTimingDays: z.number(),
    manufacturer: z.string(),
    modelNumber: z.string(),
    note: z.string(),
    imageUri: z.string().optional(),
  })
  .superRefine((values, ctx) => {
    if (values.scheduleType === "interval") {
      const n = Number(values.intervalValue);
      if (!values.intervalValue.trim() || !Number.isInteger(n) || n <= 0) {
        ctx.addIssue({
          code: "custom",
          path: ["intervalValue"],
          message: "周期は1以上の整数で入力してください",
        });
      }
    }
    if (values.scheduleType === "fixedDate" && !values.fixedDate) {
      ctx.addIssue({
        code: "custom",
        path: ["fixedDate"],
        message: "次回予定日を選択してください",
      });
    }
  });

export type ItemFormValues = z.infer<typeof formSchema>;

export type ItemFormResult = Omit<NewMaintenanceItem, "archivedAt">;

export type ItemFormInitial = Partial<
  Pick<
    ItemFormValues,
    | "name"
    | "category"
    | "taskType"
    | "location"
    | "scheduleType"
    | "intervalValue"
    | "intervalUnit"
    | "fixedDate"
    | "notificationEnabled"
    | "notificationTimingDays"
    | "manufacturer"
    | "modelNumber"
    | "note"
    | "imageUri"
    | "nextDueDateOverride"
  >
>;

export function ItemForm({
  mode,
  initial,
  caution,
  submitLabel,
  onSubmit,
}: {
  mode: "create" | "edit";
  initial?: ItemFormInitial;
  /** テンプレート由来の注意文など */
  caution?: string;
  submitLabel: string;
  onSubmit: (result: ItemFormResult) => Promise<void>;
}) {
  const [submitting, setSubmitting] = useState(false);
  const [detailsOpen, setDetailsOpen] = useState(
    Boolean(initial?.manufacturer || initial?.modelNumber || initial?.imageUri),
  );

  // このフォーム内で選んだ写真ファイル。保存されずに画面を離れたら削除する
  const pickedImagesRef = useRef<string[]>([]);
  const savedImageRef = useRef<string | undefined>(initial?.imageUri);
  useEffect(() => {
    return () => {
      for (const stored of pickedImagesRef.current) {
        if (stored !== savedImageRef.current) {
          void deleteStoredImageAsync(stored);
        }
      }
    };
  }, []);

  const {
    control,
    handleSubmit,
    watch,
    setValue,
    setError,
    formState: { errors },
  } = useForm<ItemFormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      name: initial?.name ?? "",
      category: initial?.category ?? "other",
      taskType: initial?.taskType ?? "cleaning",
      location: initial?.location ?? "",
      baseDate: mode === "create" ? todayString() : undefined,
      nextDueDateOverride: initial?.nextDueDateOverride,
      scheduleType: initial?.scheduleType ?? "interval",
      intervalValue: initial?.intervalValue ?? "",
      intervalUnit: initial?.intervalUnit ?? "month",
      fixedDate: initial?.fixedDate,
      notificationEnabled: initial?.notificationEnabled ?? true,
      notificationTimingDays: initial?.notificationTimingDays ?? 0,
      manufacturer: initial?.manufacturer ?? "",
      modelNumber: initial?.modelNumber ?? "",
      note: initial?.note ?? "",
      imageUri: initial?.imageUri,
    },
  });

  const scheduleType = watch("scheduleType");
  const intervalValue = watch("intervalValue");
  const intervalUnit = watch("intervalUnit");
  const baseDate = watch("baseDate");
  const nextDueDateOverride = watch("nextDueDateOverride");
  const location = watch("location");
  const notificationEnabled = watch("notificationEnabled");
  const imageUri = watch("imageUri");

  const intervalNumber = Number(intervalValue);
  const intervalValid =
    intervalValue.trim() !== "" &&
    Number.isInteger(intervalNumber) &&
    intervalNumber > 0;

  const previewNextDue =
    mode === "create" &&
    scheduleType === "interval" &&
    intervalValid &&
    baseDate &&
    isValidDateString(baseDate)
      ? addInterval(baseDate, intervalNumber, intervalUnit)
      : undefined;

  const submit = handleSubmit(async (values) => {
    // 次回予定日を決定する
    let nextDueDate: string | undefined;
    if (values.scheduleType === "none") {
      nextDueDate = undefined;
    } else if (values.scheduleType === "fixedDate") {
      nextDueDate = values.fixedDate;
    } else if (mode === "create") {
      if (!values.baseDate) {
        setError("baseDate", {
          message: "前回実施日または開始日を選択してください",
        });
        return;
      }
      nextDueDate = addInterval(
        values.baseDate,
        Number(values.intervalValue),
        values.intervalUnit,
      );
    } else {
      // 編集時: 手動変更があればそれを優先
      nextDueDate = values.nextDueDateOverride;
      if (!nextDueDate) {
        setError("nextDueDateOverride", {
          message: "次回予定日を選択してください",
        });
        return;
      }
    }

    const result: ItemFormResult = {
      name: values.name.trim(),
      category: values.category,
      taskType: values.taskType,
      location: values.location.trim() || undefined,
      manufacturer: values.manufacturer.trim() || undefined,
      modelNumber: values.modelNumber.trim() || undefined,
      note: values.note.trim() || undefined,
      imageUri: values.imageUri,
      scheduleType: values.scheduleType,
      intervalValue:
        values.scheduleType === "interval"
          ? Number(values.intervalValue)
          : undefined,
      intervalUnit:
        values.scheduleType === "interval" ? values.intervalUnit : undefined,
      nextDueDate,
      notificationEnabled: values.notificationEnabled,
      notificationTimingDays: values.notificationEnabled
        ? values.notificationTimingDays
        : undefined,
    };

    setSubmitting(true);
    try {
      await onSubmit(result);
      savedImageRef.current = result.imageUri;
    } finally {
      setSubmitting(false);
    }
  });

  // 元の写真ファイルの削除は保存時に呼び出し側で行う
  // （保存せずに戻った場合に登録済みの写真が消えないようにするため）
  const pickImage = async () => {
    const stored = await pickAndStoreImageAsync();
    if (!stored) return;
    if (imageUri && imageUri !== initial?.imageUri) {
      await deleteStoredImageAsync(imageUri);
    }
    pickedImagesRef.current.push(stored);
    setValue("imageUri", stored);
  };

  const removeImage = async () => {
    if (imageUri && imageUri !== initial?.imageUri) {
      await deleteStoredImageAsync(imageUri);
    }
    setValue("imageUri", undefined);
  };

  return (
    <KeyboardAvoidingView
      style={styles.flex}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <ScrollView
        style={styles.flex}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        {caution ? <NoteText text={caution} /> : null}

        <FormSection title="基本情報">
          <Controller
            control={control}
            name="name"
            render={({ field }) => (
              <TextField
                label="項目名"
                required
                value={field.value}
                onChangeText={field.onChange}
                placeholder="例：エアコンフィルター"
                error={errors.name?.message}
              />
            )}
          />
          <Controller
            control={control}
            name="taskType"
            render={({ field }) => (
              <ChipSelect
                label="作業種別"
                required
                options={(
                  Object.keys(TASK_TYPE_LABELS) as MaintenanceTaskType[]
                ).map((v) => ({ value: v, label: TASK_TYPE_LABELS[v] }))}
                value={field.value}
                onChange={field.onChange}
                error={errors.taskType?.message}
              />
            )}
          />
          <Controller
            control={control}
            name="category"
            render={({ field }) => (
              <ChipSelect
                label="カテゴリー"
                options={(
                  Object.keys(CATEGORY_LABELS) as MaintenanceCategory[]
                ).map((v) => ({ value: v, label: CATEGORY_LABELS[v] }))}
                value={field.value}
                onChange={field.onChange}
              />
            )}
          />
          <Controller
            control={control}
            name="location"
            render={({ field }) => (
              <TextField
                label="設置場所"
                value={field.value}
                onChangeText={field.onChange}
                placeholder="例：リビング"
              />
            )}
          />
          <ChipSelect
            options={LOCATION_SUGGESTIONS.map((v) => ({ value: v, label: v }))}
            value={LOCATION_SUGGESTIONS.includes(location) ? location : undefined}
            onChange={(v) => setValue("location", v)}
          />
          {mode === "create" ? (
            <Controller
              control={control}
              name="baseDate"
              render={({ field }) => (
                <DateField
                  label="前回実施日または開始日"
                  required
                  value={field.value}
                  onChange={field.onChange}
                  error={errors.baseDate?.message}
                />
              )}
            />
          ) : null}
        </FormSection>

        <FormSection title="次回目安">
          <Controller
            control={control}
            name="scheduleType"
            render={({ field }) => (
              <ChipSelect
                label="設定方法"
                required
                options={(
                  Object.keys(SCHEDULE_TYPE_LABELS) as ScheduleType[]
                ).map((v) => ({ value: v, label: SCHEDULE_TYPE_LABELS[v] }))}
                value={field.value}
                onChange={field.onChange}
              />
            )}
          />
          {scheduleType === "interval" ? (
            <>
              <View style={styles.intervalRow}>
                <View style={styles.intervalValue}>
                  <Controller
                    control={control}
                    name="intervalValue"
                    render={({ field }) => (
                      <TextField
                        label="周期"
                        required
                        value={field.value}
                        onChangeText={field.onChange}
                        placeholder="例：30"
                        keyboardType="number-pad"
                        error={errors.intervalValue?.message}
                      />
                    )}
                  />
                </View>
                <View style={styles.intervalUnit}>
                  <Controller
                    control={control}
                    name="intervalUnit"
                    render={({ field }) => (
                      <ChipSelect
                        label="単位"
                        options={(
                          Object.keys(INTERVAL_UNIT_LABELS) as IntervalUnit[]
                        ).map((v) => ({
                          value: v,
                          label: INTERVAL_UNIT_LABELS[v],
                        }))}
                        value={field.value}
                        onChange={field.onChange}
                      />
                    )}
                  />
                </View>
              </View>
              {previewNextDue ? (
                <Text style={styles.preview}>
                  次回目安：{formatDateJa(previewNextDue)}
                </Text>
              ) : null}
              {mode === "edit" ? (
                <Controller
                  control={control}
                  name="nextDueDateOverride"
                  render={({ field }) => (
                    <DateField
                      label="次回予定日"
                      required
                      value={field.value}
                      onChange={field.onChange}
                      error={errors.nextDueDateOverride?.message}
                    />
                  )}
                />
              ) : null}
            </>
          ) : null}
          {scheduleType === "fixedDate" ? (
            <Controller
              control={control}
              name="fixedDate"
              render={({ field }) => (
                <DateField
                  label="次回予定日"
                  required
                  value={field.value}
                  onChange={field.onChange}
                  error={errors.fixedDate?.message}
                />
              )}
            />
          ) : null}
          {scheduleType === "none" ? (
            <Text style={styles.helper}>
              予定日は設定せず、実施した記録だけを残します。
            </Text>
          ) : null}
          <NoteText text={GUIDANCE_NOTE} />
        </FormSection>

        <FormSection title="通知">
          <Controller
            control={control}
            name="notificationEnabled"
            render={({ field }) => (
              <SwitchRow
                label="予定日前に通知する"
                value={field.value}
                onChange={field.onChange}
              />
            )}
          />
          {notificationEnabled ? (
            <Controller
              control={control}
              name="notificationTimingDays"
              render={({ field }) => (
                <ChipSelect
                  label="通知するタイミング"
                  options={NOTIFICATION_TIMING_OPTIONS.map((o) => ({
                    value: o.days,
                    label: o.label,
                  }))}
                  value={field.value}
                  onChange={field.onChange}
                />
              )}
            />
          ) : null}
        </FormSection>

        <Pressable
          accessibilityRole="button"
          onPress={() => setDetailsOpen((v) => !v)}
          style={styles.detailsToggle}
        >
          <Text style={styles.detailsToggleText}>
            {detailsOpen ? "▼" : "▶"} 詳細情報（メーカー・型番・写真）
          </Text>
        </Pressable>
        {detailsOpen ? (
          <FormSection title="製品情報">
            <Controller
              control={control}
              name="manufacturer"
              render={({ field }) => (
                <TextField
                  label="メーカー名"
                  value={field.value}
                  onChangeText={field.onChange}
                />
              )}
            />
            <Controller
              control={control}
              name="modelNumber"
              render={({ field }) => (
                <TextField
                  label="型番"
                  value={field.value}
                  onChangeText={field.onChange}
                />
              )}
            />
            {imageUri ? (
              <View style={styles.imageBlock}>
                <Image
                  source={{ uri: resolveImageUri(imageUri) }}
                  style={styles.image}
                />
                <AppButton
                  title="写真を削除"
                  variant="ghost"
                  onPress={removeImage}
                />
              </View>
            ) : (
              <AppButton
                title="写真を追加"
                variant="secondary"
                onPress={pickImage}
              />
            )}
          </FormSection>
        ) : null}

        <FormSection title="メモ">
          <Controller
            control={control}
            name="note"
            render={({ field }) => (
              <TextField
                label="メモ"
                value={field.value}
                onChangeText={field.onChange}
                placeholder="使う洗剤、手順のポイントなど"
                multiline
              />
            )}
          />
        </FormSection>
      </ScrollView>
      <View style={styles.footer}>
        <AppButton title={submitLabel} onPress={submit} loading={submitting} />
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.background },
  content: {
    padding: spacing.lg,
    paddingBottom: spacing.xxl,
    gap: spacing.md,
  },
  intervalRow: {
    flexDirection: "row",
    gap: spacing.md,
  },
  intervalValue: { flex: 2 },
  intervalUnit: { flex: 3 },
  preview: {
    fontSize: fontSize.md,
    color: colors.primary,
    fontWeight: "600",
    marginBottom: spacing.md,
  },
  helper: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
    marginBottom: spacing.md,
    lineHeight: 19,
  },
  detailsToggle: {
    paddingVertical: spacing.sm,
    marginBottom: spacing.md,
  },
  detailsToggleText: {
    fontSize: fontSize.md,
    color: colors.primary,
    fontWeight: "600",
  },
  imageBlock: {
    gap: spacing.sm,
  },
  image: {
    width: "100%",
    height: 180,
    borderRadius: radius.md,
    backgroundColor: colors.background,
  },
  footer: {
    padding: spacing.lg,
    backgroundColor: colors.surface,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
});
