#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hid/IOHIDManager.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int report_count = 0;

static void report_callback(void *context,
                            IOReturn result,
                            void *sender,
                            IOHIDReportType type,
                            uint32_t reportID,
                            uint8_t *report,
                            CFIndex reportLength) {
    (void)context;
    (void)sender;
    (void)type;

    report_count++;
    printf("#%04d id=%u len=%ld data=", report_count, reportID, (long)reportLength);
    CFIndex limit = reportLength < 32 ? reportLength : 32;
    for (CFIndex i = 0; i < limit; i++) {
        printf("%02x", report[i]);
        if (i + 1 < limit) printf(" ");
    }
    if (reportLength > limit) printf(" ...");
    printf("\n");
    fflush(stdout);
}

static void device_matched(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    (void)context;
    (void)result;
    (void)sender;

    CFStringRef product = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    char product_name[256] = "(unknown)";
    if (product) {
        CFStringGetCString(product, product_name, sizeof(product_name), kCFStringEncodingUTF8);
    }

    printf("Matched HID device: %s\n", product_name);
    fflush(stdout);

    uint8_t *buffer = calloc(1, 512);
    if (!buffer) {
        fprintf(stderr, "Failed to allocate report buffer\n");
        return;
    }

    IOHIDDeviceRegisterInputReportCallback(device, buffer, 512, report_callback, NULL);
}

static CFNumberRef number(int value) {
    return CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
}

int main(void) {
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!manager) {
        fprintf(stderr, "Failed to create IOHIDManager\n");
        return 1;
    }

    int vendor = 0x056a;
    int product = 0x0027;

    CFNumberRef vendor_ref = number(vendor);
    CFNumberRef product_ref = number(product);

    const void *keys[] = {
        CFSTR(kIOHIDVendorIDKey),
        CFSTR(kIOHIDProductIDKey)
    };
    const void *values[] = {
        vendor_ref,
        product_ref
    };

    CFDictionaryRef match = CFDictionaryCreate(
        kCFAllocatorDefault,
        keys,
        values,
        2,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );

    IOHIDManagerSetDeviceMatching(manager, match);
    IOHIDManagerRegisterDeviceMatchingCallback(manager, device_matched, NULL);
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    IOReturn open_result = IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone);
    if (open_result != kIOReturnSuccess) {
        fprintf(stderr, "Failed to open IOHIDManager: 0x%x\n", open_result);
        return 2;
    }

    printf("Monitoring Wacom Intuos5 touch M raw HID reports.\n");
    printf("Move/press the pen for 10 seconds. Press Ctrl+C to stop earlier.\n");
    fflush(stdout);

    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10.0, false);

    printf("Done. Reports captured: %d\n", report_count);
    fflush(stdout);

    IOHIDManagerClose(manager, kIOHIDOptionsTypeNone);
    CFRelease(match);
    CFRelease(vendor_ref);
    CFRelease(product_ref);
    CFRelease(manager);
    return 0;
}
