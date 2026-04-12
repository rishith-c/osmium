/* ===========================================================================
 * rtc.c - Real-Time Clock (CMOS) Driver Implementation
 * ===========================================================================
 * The CMOS RTC is accessed via two I/O ports:
 *   0x70 - Address/register select (write the register number here)
 *   0x71 - Data (read the value here)
 *
 * RTC registers:
 *   0x00 - Seconds        0x04 - Hours
 *   0x02 - Minutes        0x07 - Day of month
 *   0x08 - Month          0x09 - Year
 *   0x0A - Status A (bit 7 = update in progress)
 *   0x0B - Status B (bit 1 = 24h mode, bit 2 = binary mode)
 *
 * By default, values are in BCD (Binary Coded Decimal), where each
 * nibble represents a decimal digit. E.g., 0x59 = 59 decimal.
 * =========================================================================== */

#include "rtc.h"
#include "ports.h"
#include "screen.h"

/* ---------------------------------------------------------------------------
 * cmos_read - Read a single CMOS register
 * --------------------------------------------------------------------------- */
static unsigned char cmos_read(unsigned char reg)
{
    outb(0x70, reg);
    return inb(0x71);
}

/* ---------------------------------------------------------------------------
 * bcd_to_binary - Convert BCD to binary
 * ---------------------------------------------------------------------------
 * BCD stores each decimal digit in a nibble:
 *   0x59 -> upper=5, lower=9 -> 5*10 + 9 = 59
 * --------------------------------------------------------------------------- */
static unsigned char bcd_to_binary(unsigned char bcd)
{
    return ((bcd >> 4) * 10) + (bcd & 0x0F);
}

/* ---------------------------------------------------------------------------
 * rtc_wait_ready - Wait until the RTC is not updating
 * ---------------------------------------------------------------------------
 * Status Register A bit 7 is set while the RTC is updating its registers.
 * We must wait for it to clear before reading to avoid inconsistent values.
 * --------------------------------------------------------------------------- */
static void rtc_wait_ready(void)
{
    while (cmos_read(0x0A) & 0x80) {
        /* Spin until update-in-progress flag clears */
    }
}

/* ---------------------------------------------------------------------------
 * rtc_read_time - Read current date/time from CMOS RTC
 * --------------------------------------------------------------------------- */
void rtc_read_time(rtc_time_t *time)
{
    rtc_wait_ready();

    unsigned char raw_seconds = cmos_read(0x00);
    unsigned char raw_minutes = cmos_read(0x02);
    unsigned char raw_hours   = cmos_read(0x04);
    unsigned char raw_day     = cmos_read(0x07);
    unsigned char raw_month   = cmos_read(0x08);
    unsigned char raw_year    = cmos_read(0x09);

    /* Check Status Register B to see if values are BCD or binary */
    unsigned char status_b = cmos_read(0x0B);

    if (!(status_b & 0x04)) {
        /* BCD mode - convert to binary */
        time->seconds = bcd_to_binary(raw_seconds);
        time->minutes = bcd_to_binary(raw_minutes);
        time->hours   = bcd_to_binary(raw_hours & 0x7F); /* Mask AM/PM bit */
        time->day     = bcd_to_binary(raw_day);
        time->month   = bcd_to_binary(raw_month);
        time->year    = bcd_to_binary(raw_year);
    } else {
        /* Binary mode */
        time->seconds = raw_seconds;
        time->minutes = raw_minutes;
        time->hours   = raw_hours & 0x7F;
        time->day     = raw_day;
        time->month   = raw_month;
        time->year    = raw_year;
    }

    /* Handle 12-hour mode: convert to 24-hour */
    if (!(status_b & 0x02) && (raw_hours & 0x80)) {
        time->hours = (time->hours + 12) % 24;
    }
}

/* ---------------------------------------------------------------------------
 * print_two_digits - Print a number as exactly two digits (zero-padded)
 * --------------------------------------------------------------------------- */
static void print_two_digits(unsigned char val)
{
    char buf[3];
    buf[0] = '0' + (val / 10);
    buf[1] = '0' + (val % 10);
    buf[2] = '\0';
    print_string(buf);
}

/* ---------------------------------------------------------------------------
 * rtc_print_datetime - Print formatted date and time
 * --------------------------------------------------------------------------- */
void rtc_print_datetime(void)
{
    rtc_time_t time;
    rtc_read_time(&time);

    /* Date: YYYY-MM-DD */
    print_string("20");
    print_two_digits(time.year);
    print_string("-");
    print_two_digits(time.month);
    print_string("-");
    print_two_digits(time.day);

    print_string(" ");

    /* Time: HH:MM:SS */
    print_two_digits(time.hours);
    print_string(":");
    print_two_digits(time.minutes);
    print_string(":");
    print_two_digits(time.seconds);
}
