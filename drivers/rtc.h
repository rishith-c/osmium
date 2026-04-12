/* ===========================================================================
 * rtc.h - Real-Time Clock (CMOS) Driver
 * ===========================================================================
 * Reads the current date and time from the CMOS Real-Time Clock.
 * The RTC maintains time even when the computer is powered off
 * (powered by a small battery on the motherboard).
 * =========================================================================== */

#ifndef RTC_H
#define RTC_H

/* Time/date structure */
typedef struct {
    unsigned char seconds;
    unsigned char minutes;
    unsigned char hours;
    unsigned char day;
    unsigned char month;
    unsigned char year;      /* Two-digit year (e.g., 26 for 2026) */
} rtc_time_t;

/* Read the current time from the RTC */
void rtc_read_time(rtc_time_t *time);

/* Print the current date and time to screen */
void rtc_print_datetime(void);

#endif /* RTC_H */
