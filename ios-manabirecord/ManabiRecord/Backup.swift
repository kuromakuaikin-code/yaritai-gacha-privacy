import Foundation
import SwiftData

// MARK: - バックアップ用JSON構造（4モジュール分をまとめて1ファイルに）

struct BackupLessonSession: Codable {
    var date: String
    var attended: Bool
    var memo: String
}

struct BackupLessonCourse: Codable {
    var childName: String
    var courseName: String
    var monthlyFee: Int
    var dayOfWeekNote: String
    var memo: String
    var sessions: [BackupLessonSession]
}

struct BackupBook: Codable {
    var childName: String
    var title: String
    var author: String
    var finishedDate: String
    var rating: Int
    var pages: Int?
    var summary: String
}

struct BackupStudyLog: Codable {
    var date: String
    var minutesStudied: Int
    var memo: String
}

struct BackupStudyGoal: Codable {
    var title: String
    var targetDate: String
    var totalMinutesGoal: Int
    var memo: String
    var logs: [BackupStudyLog]
}

struct BackupChecklistEntry: Codable {
    var text: String
    var isChecked: Bool
}

struct BackupSchoolEvent: Codable {
    var title: String
    var date: String
    var memo: String
    var entries: [BackupChecklistEntry]
}

struct BackupFile: Codable {
    var app = "ManabiRecord"
    var version = 1
    var exportedAt: String
    var lessonCourses: [BackupLessonCourse]
    var books: [BackupBook]
    var studyGoals: [BackupStudyGoal]
    var schoolEvents: [BackupSchoolEvent]
}

enum BackupService {
    static func export(
        courses: [LessonCourse],
        books: [BookRecord],
        goals: [StudyGoal],
        events: [SchoolEvent]
    ) -> Data? {
        let backup = BackupFile(
            exportedAt: ISODay.string(Date()),
            lessonCourses: courses.map { course in
                BackupLessonCourse(
                    childName: course.childName,
                    courseName: course.courseName,
                    monthlyFee: course.monthlyFee,
                    dayOfWeekNote: course.dayOfWeekNote,
                    memo: course.memo,
                    sessions: course.sessions.map {
                        BackupLessonSession(date: ISODay.string($0.date), attended: $0.attended, memo: $0.memo)
                    }
                )
            },
            books: books.map {
                BackupBook(
                    childName: $0.childName,
                    title: $0.title,
                    author: $0.author,
                    finishedDate: ISODay.string($0.finishedDate),
                    rating: $0.rating,
                    pages: $0.pages,
                    summary: $0.summary
                )
            },
            studyGoals: goals.map { goal in
                BackupStudyGoal(
                    title: goal.title,
                    targetDate: ISODay.string(goal.targetDate),
                    totalMinutesGoal: goal.totalMinutesGoal,
                    memo: goal.memo,
                    logs: goal.logs.map {
                        BackupStudyLog(date: ISODay.string($0.date), minutesStudied: $0.minutesStudied, memo: $0.memo)
                    }
                )
            },
            schoolEvents: events.map { event in
                BackupSchoolEvent(
                    title: event.title,
                    date: ISODay.string(event.date),
                    memo: event.memo,
                    entries: event.entries.map {
                        BackupChecklistEntry(text: $0.text, isChecked: $0.isChecked)
                    }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    /// インポートした件数（4モジュールの登録件数の合計）を返す。失敗時は nil
    @discardableResult
    static func importData(_ data: Data, into context: ModelContext) -> Int? {
        guard let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else { return nil }
        var count = 0

        for item in backup.lessonCourses {
            let course = LessonCourse()
            course.childName = item.childName
            course.courseName = item.courseName
            course.monthlyFee = item.monthlyFee
            course.dayOfWeekNote = item.dayOfWeekNote
            course.memo = item.memo
            context.insert(course)
            for s in item.sessions {
                let session = LessonSession()
                session.date = ISODay.date(s.date) ?? Date()
                session.attended = s.attended
                session.memo = s.memo
                session.course = course
                context.insert(session)
                course.sessions.append(session)
            }
            count += 1
        }

        for item in backup.books {
            let book = BookRecord()
            book.childName = item.childName
            book.title = item.title
            book.author = item.author
            book.finishedDate = ISODay.date(item.finishedDate) ?? Date()
            book.rating = item.rating
            book.pages = item.pages
            book.summary = item.summary
            context.insert(book)
            count += 1
        }

        for item in backup.studyGoals {
            let goal = StudyGoal()
            goal.title = item.title
            goal.targetDate = ISODay.date(item.targetDate) ?? Date()
            goal.totalMinutesGoal = item.totalMinutesGoal
            goal.memo = item.memo
            context.insert(goal)
            for l in item.logs {
                let log = StudyLog()
                log.date = ISODay.date(l.date) ?? Date()
                log.minutesStudied = l.minutesStudied
                log.memo = l.memo
                log.goal = goal
                context.insert(log)
                goal.logs.append(log)
            }
            count += 1
        }

        for item in backup.schoolEvents {
            let event = SchoolEvent()
            event.title = item.title
            event.date = ISODay.date(item.date) ?? Date()
            event.memo = item.memo
            context.insert(event)
            for e in item.entries {
                let entry = ChecklistEntry()
                entry.text = e.text
                entry.isChecked = e.isChecked
                entry.event = event
                context.insert(entry)
                event.entries.append(entry)
            }
            count += 1
        }

        return count
    }
}
