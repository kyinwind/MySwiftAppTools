//
//  DateTools.swift
//  NianFoAssistant
//
//  Created by xuehui yang on 2023/5/16.
//

import Foundation

class DateTools {
    //判断一个日期是否在当月
    static func isDateInCurrentMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current

        // 获取当前日期的年和月
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())

        // 获取要比较日期的年和月
        let dateYear = calendar.component(.year, from: date)
        let dateMonth = calendar.component(.month, from: date)

        // 比较年和月是否相等
        return currentYear == dateYear && currentMonth == dateMonth
    }
    //根据传递的日期，得到一个"yyyy-MM"格式的表示月份的字符串
    static func getMonthStringByDate(date:Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let datetime = formatter.string(from: date)
        return datetime
    }
    //根据传递的String日期，得到一个"yyyy-MM"格式的表示月份的字符串
    static func getMonthStringByDateString(date:String) -> String {
        let date = getDateByString(string: date,dateFormat: "yyyy-MM-dd")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let datetime = formatter.string(from: date)
        return datetime
    }
    //根据传递的日期，得到一个"yyyy-MM-dd"格式的日期字符串
    static func getStringByDate(date:Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let datetime = formatter.string(from: date)
        return datetime
    }
    //根据传递的时间，得到一个"yyyy-MM-dd HH:mm:ss"格式的时间字符串
    static func getStringByDateTime(_ date:Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ss"
        let datetime = formatter.string(from: date)
        return datetime
    }
    //由今天的日期，得到一个字符串的日期，指定格式是"yyyy-MM-dd"
    static func getStringByCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        let datetime = formatter.string(from: Date())
        return datetime
    }
    //由今天的日期时间，得到一个字符串的时间，指定格式是"yyyy-MM-dd HH:mm"
    static func getDateTimeStringByCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let datetime = formatter.string(from: Date())
        return datetime
    }
    //只要当前的小时和分钟
    static func getTimeStringByCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm"
        let datetime = formatter.string(from: Date())
        return datetime
    }
    /// Date类型转化为日期字符串
    ///
    /// - Parameters:
    ///   - date: Date类型
    ///   - dateFormat: 格式化样式默认“yyyy-MM-dd”
    /// - Returns: 日期字符串
    static func getDateStringByDate(date:Date, dateFormat:String="yyyy-MM-dd") -> String {
        let timeZone = TimeZone.init(identifier: "UTC")
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale.init(identifier: "zh_CN")
        formatter.dateFormat = dateFormat
        let date = formatter.string(from: date)
        return date.components(separatedBy: " ").first!
    }
    static func getMonthStringByDate(date:Date, dateFormat:String="yyyy-MM") -> String {
        let timeZone = TimeZone.init(identifier: "UTC")
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale.init(identifier: "zh_CN")
        formatter.dateFormat = dateFormat
        let date = formatter.string(from: date)
        return date.components(separatedBy: " ").first!
    }
    /// 日期字符串转化为Date类型
    ///
    /// - Parameters:
    ///   - string: 日期字符串
    ///   - dateFormat: 格式化样式，默认为“yyyy-MM-dd HH:mm:ss”
    /// - Returns: Date类型
    static func getDateByString(string:String, dateFormat:String? = nil) -> Date {
        let dateFormatter = DateFormatter.init()
        if let df = dateFormat,df != "" {
            dateFormatter.dateFormat = dateFormat
        }else{
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        let date = dateFormatter.date(from: string)
        return date!
    }
    //由一个月份的字符串转换成时间Date格式
    static func getDateByMonthString(string:String) -> Date {
        //print("getDateByMonthString--------------string:\(string)")
        let timeZone = TimeZone.init(identifier: "UTC")
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale.init(identifier: "zh_CN")
        
        let dateFormatter = formatter
        dateFormatter.dateFormat = "yyyy-MM"
        let date = dateFormatter.date(from: string)
        return date!
    }
    //由一个数字转换为百分比
    static func getPercentageByNumber(_ number: Double) -> String {
        //print(number)
        let formatter = NumberFormatter()
        
        formatter.numberStyle = .percent
        
        formatter.percentSymbol = ""
        
        return formatter.string(from: NSNumber(value:number))!
        
    }
    
    static func getDateDiff(start:String,end:String) -> Int {
        // 计算两个日期差，返回相差天数,如果 end - start 大于 0，返回也是大于 0
        let formatter = DateFormatter()
        let calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        // 开始日期
        let startDate = formatter.date(from: start)
        
        // 结束日期
        let endDate = formatter.date(from: end)
        let diff:DateComponents = calendar.dateComponents([.day], from: startDate!, to: endDate!)
        return diff.day!
    }
    static func getDateDiff(start:Date,end:Date) -> Int {
        // 计算两个日期差，返回相差天数
        let formatter = DateFormatter()
        let calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let diff:DateComponents = calendar.dateComponents([.day], from: startDay, to: endDay)
//        print("startdate:\(start)")
//        print("enddate:\(end)")
//        print("相差：\(String(describing: diff.day))")
        return diff.day!
    }
    //计算某个日期之后N个月是哪一天
    static func getDayAfterMonths(startDate:Date,months:Int)->Date{
        let calendar = Calendar.current
        // 获取当前日期
        let currentDate = startDate
        // 在当前日期的基础上增加2个月
        let MonthsLater = calendar.date(byAdding:.month, value: months, to: currentDate)!
        // 格式化日期
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy-MM-dd"
//        let formattedDate = dateFormatter.string(from: MonthsLater)
//        print(formattedDate)
        return MonthsLater
    }
    //计算某个日期之前N个月是哪一天
    static func getDayBeforeMonths(startDate:Date,months:Int)->Date{
        let calendar = Calendar.current
        // 获取当前日期
        let currentDate = startDate
        // 在当前日期的基础上增加2个月
        let MonthsBefore = calendar.date(byAdding:.month, value: -months, to: currentDate)!
        // 格式化日期
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy-MM-dd"
//        let formattedDate = dateFormatter.string(from: MonthsLater)
//        print(formattedDate)
        return MonthsBefore
    }
    ///计算某个日期之后n天的日期
    static func getDateAfterDays(from date: Date, days: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding:.day, value: days, to: date)!
    }
    static let buddhaHoliDay:[String:String] = ["1-1":"正月初一弥勒菩萨圣诞",
                                                   "1-6":"正月初六定光佛圣诞",
                                                   "2-8":"二月初八释迦牟尼佛出家",
                                                   "2-15":"二月十五日释迦牟尼佛涅",
                                                   "2-19":"二月十九日观音菩萨圣诞",
                                                   "2-21":"二月二十一日普贤菩萨圣诞",
                                                   "3-16":"三月十六日准提菩萨圣诞",
                                                   "4-4":"四月初四文殊菩萨圣诞",
                                                   "4-8":"四月初八释迦牟尼佛圣诞",
                                                   "4-28":"四月二十八日药王菩萨圣诞",
                                                   "5-13":"五月十三日伽蓝菩萨圣诞",
                                                   "6-3":"六月初三韦驮菩萨圣诞",
                                                   "6-19":"六月十九日观音菩萨成道",
                                                   "7-13":"七月十三日大势至菩萨圣诞",
                                                   "7-15":"七月十五日佛欢喜日",
                                                   "7-24":"七月二十四日龙树菩萨圣诞",
                                                   "7-30":"七月三十日地藏菩萨圣诞",
                                                   "8-15":"八月十五日月光菩萨圣诞",
                                                   "8-22":"八月二十二日燃灯古佛圣诞",
                                                   "9-19":"九月十九日观音菩萨出家",
                                                   "9-30":"九月三十日药师佛圣诞",
                                                   "11-17":"十一月十七日阿弥陀佛圣诞",
                                                   "11-19":"十一月十九日日光菩萨圣诞",
                                                   "12-8":"十二月初八释迦牟尼佛成道",
                                                   "12-23":"十二月二十三日监斋菩萨圣诞",
                                                   "12-29":"十二月二十九日华严菩萨圣诞"]
    
    //计算当天有哪些佛教节日
    static func getBuddhaHolidayInfo(date:Date)->String{
        //初始化农历日历
        let lunarCalendar = Calendar.init(identifier: .chinese)
        
//        ///获得农历月
//        let lunarMonth = DateFormatter()
//        lunarMonth.locale = Locale(identifier: "zh_CN")
//        lunarMonth.dateStyle = .medium
//        lunarMonth.calendar = lunarCalendar
//        lunarMonth.dateFormat = "MMM"
//        
//        let month = lunarMonth.string(from: date)
//        
//        
//        //获得农历日
//        let lunarDay = DateFormatter()
//        lunarDay.locale = Locale(identifier: "zh_CN")
//        lunarDay.dateStyle = .medium
//        lunarDay.calendar = lunarCalendar
//        lunarDay.dateFormat = "d"
//        
//        let day = lunarDay.string(from: date)
        ///生成农历的key
        let lunarFormatter = DateFormatter()
        lunarFormatter.locale = Locale(identifier: "zh_CN")
        lunarFormatter.dateStyle = .short
        lunarFormatter.calendar = lunarCalendar
        lunarFormatter.dateFormat = "M-d"
        
        let lunar = lunarFormatter.string(from: date)
        ///生成公历日历的Key 用于查询字典
        let gregorianFormatter = DateFormatter()
        gregorianFormatter.locale = Locale(identifier: "zh_CN")
        gregorianFormatter.dateFormat = "M-d"
        
        let gregorian = gregorianFormatter.string(from: date)
        
        //print("month:\(month),day:\(day),lunar:\(lunar),gregorian\(gregorian)")
        if let holiday = getBuddhaHoliday(lunarKey: lunar, gregorKey: gregorian) {
            return holiday
        }
        return ""
    }
    
    
    static func getBuddhaHoliday(lunarKey: String, gregorKey: String) -> String?{
        
        ///当前农历节日优先返回
        if let holiday = buddhaHoliDay[lunarKey]{
            return holiday
        }

        return nil
    }
    //返回佛教节日字符串
    static func getBuddhaDaysText()->String {
        let str = """
正月初一弥勒菩萨圣诞
正月初六定光佛圣诞
二月初八释迦牟尼佛出家
二月十五日释迦牟尼佛涅
二月十九日观音菩萨圣诞
二月二十一日普贤菩萨圣诞
三月十六日准提菩萨圣诞
四月初四文殊菩萨圣诞
四月初八释迦牟尼佛圣诞
四月二十八日药王菩萨圣诞
五月十三日伽蓝菩萨圣诞
六月初三韦驮菩萨圣诞
六月十九日观音菩萨成道
七月十三日大势至菩萨圣诞
七月十五日佛欢喜日
七月二十四日龙树菩萨圣诞
七月三十日地藏菩萨圣诞
八月十五日月光菩萨圣诞
八月二十二日燃灯古佛圣诞
九月十九日观音菩萨出家
九月三十日药师佛圣诞
十一月十七日阿弥陀佛圣诞
十一月十九日日光菩萨圣诞
十二月初八释迦牟尼佛成道
十二月二十三日监斋菩萨圣诞
十二月二十九日华严菩萨圣诞
"""
        return str
    }
}

extension DateFormatter {
    static let zipName: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        return df
    }()
}
