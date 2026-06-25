using Gtk;
using Cairo;

public class BatteryChart : Gtk.DrawingArea {
    private Json.Array data;
    private int time_range_hours = 1;
    private const int PADDING_LEFT = 50;
    private const int PADDING_RIGHT = 20;
    private const int PADDING_TOP = 20;
    private const int PADDING_BOTTOM = 30;

    public BatteryChart () {
        data = new Json.Array ();
        set_size_request (400, 250);
    }

    public void set_data (Json.Array new_data) {
        data = new_data;
        queue_draw ();
    }

    public void set_time_range (int hours) {
        time_range_hours = hours;
        queue_draw ();
    }

    private int64 get_now () {
        return GLib.get_real_time () / 1000000;
    }

    private string format_time (int64 timestamp) {
        var dt = new GLib.DateTime.from_unix_local (timestamp);
        return dt.format ("%H:%M");
    }

    public override bool draw (Cairo.Context cr) {
        int width = get_allocated_width ();
        int height = get_allocated_height ();

        draw_background (cr, width, height);
        draw_grid (cr, width, height);
        draw_axes (cr, width, height);

        if (data.get_length () > 1) {
            draw_line (cr, width, height);
            draw_points (cr, width, height);
        }

        return true;
    }

    private void draw_background (Cairo.Context cr, int width, int height) {
        cr.set_source_rgb (1.0, 1.0, 1.0);
        cr.rectangle (0, 0, width, height);
        cr.fill ();
    }

    private void draw_grid (Cairo.Context cr, int width, int height) {
        cr.set_source_rgb (0.9, 0.9, 0.9);
        cr.set_line_width (0.5);

        for (int i = 0; i <= 4; i++) {
            double y = PADDING_TOP + (height - PADDING_TOP - PADDING_BOTTOM) * i / 4.0;
            cr.move_to (PADDING_LEFT, y);
            cr.line_to (width - PADDING_RIGHT, y);
            cr.stroke ();
        }

        for (int i = 0; i <= 6; i++) {
            double x = PADDING_LEFT + (width - PADDING_LEFT - PADDING_RIGHT) * i / 6.0;
            cr.move_to (x, PADDING_TOP);
            cr.line_to (x, height - PADDING_BOTTOM);
            cr.stroke ();
        }
    }

    private void draw_axes (Cairo.Context cr, int width, int height) {
        cr.set_source_rgb (0.0, 0.0, 0.0);
        cr.set_line_width (1.0);

        cr.move_to (PADDING_LEFT, PADDING_TOP);
        cr.line_to (PADDING_LEFT, height - PADDING_BOTTOM);
        cr.line_to (width - PADDING_RIGHT, height - PADDING_BOTTOM);
        cr.stroke ();

        cr.set_font_size (11);
        for (int i = 0; i <= 4; i++) {
            int value = 100 - i * 25;
            double y = PADDING_TOP + (height - PADDING_TOP - PADDING_BOTTOM) * i / 4.0;
            cr.move_to (PADDING_LEFT - 35, y + 4);
            cr.show_text ("%d%%".printf (value));
        }

        draw_time_labels (cr, width, height);
    }

    private void draw_time_labels (Cairo.Context cr, int width, int height) {
        int64 now = get_now ();
        int64 start_time = now - (time_range_hours * 3600);

        cr.set_font_size (10);
        for (int i = 0; i <= 6; i++) {
            double x = PADDING_LEFT + (width - PADDING_LEFT - PADDING_RIGHT) * i / 6.0;
            int64 t = start_time + (time_range_hours * 3600 * i / 6);
            string label = format_time (t);
            cr.move_to (x - 15, height - PADDING_BOTTOM + 15);
            cr.show_text (label);
        }
    }

    private void draw_line (Cairo.Context cr, int width, int height) {
        if (data.get_length () < 2) return;

        double plot_width = width - PADDING_LEFT - PADDING_RIGHT;
        double plot_height = height - PADDING_TOP - PADDING_BOTTOM;

        int64 now = get_now ();
        int64 start_time = now - (time_range_hours * 3600);

        cr.set_source_rgb (0.2, 0.6, 1.0);
        cr.set_line_width (2.0);

        bool first = true;
        for (int i = 0; i < data.get_length (); i++) {
            var entry = data.get_object_element (i);
            int64 timestamp = entry.get_int_member ("timestamp");
            int capacity = (int) entry.get_int_member ("capacity");

            double x = PADDING_LEFT + plot_width * (timestamp - start_time) / (double) (time_range_hours * 3600);
            double y = PADDING_TOP + plot_height * (1.0 - capacity / 100.0);

            if (x < PADDING_LEFT) continue;

            if (first) {
                cr.move_to (x, y);
                first = false;
            } else {
                cr.line_to (x, y);
            }
        }
        cr.stroke ();
    }

    private void draw_points (Cairo.Context cr, int width, int height) {
        double plot_width = width - PADDING_LEFT - PADDING_RIGHT;
        double plot_height = height - PADDING_TOP - PADDING_BOTTOM;

        int64 now = get_now ();
        int64 start_time = now - (time_range_hours * 3600);

        cr.set_source_rgb (0.2, 0.6, 1.0);

        for (int i = 0; i < data.get_length (); i++) {
            var entry = data.get_object_element (i);
            int64 timestamp = entry.get_int_member ("timestamp");
            int capacity = (int) entry.get_int_member ("capacity");

            double x = PADDING_LEFT + plot_width * (timestamp - start_time) / (double) (time_range_hours * 3600);
            double y = PADDING_TOP + plot_height * (1.0 - capacity / 100.0);

            if (x < PADDING_LEFT) continue;

            cr.arc (x, y, 3, 0, 2 * Math.PI);
            cr.fill ();
        }
    }
}
