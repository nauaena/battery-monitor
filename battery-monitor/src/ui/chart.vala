using Gtk;
using Cairo;

public class BatteryChart : Gtk.DrawingArea {
    private Json.Array data;
    private int time_range_hours = 1;
    private int chart_mode = 0;  // 0=电量, 1=充电功率, 2=放电功率
    private const int PADDING_LEFT = 50;
    private const int PADDING_RIGHT = 50;
    private const int PADDING_TOP = 30;
    private const int PADDING_BOTTOM = 30;

    // 曲线颜色
    private const double CAPACITY_R = 0.2;
    private const double CAPACITY_G = 0.6;
    private const double CAPACITY_B = 1.0;
    private const double CHARGE_R = 0.0;
    private const double CHARGE_G = 0.8;
    private const double CHARGE_B = 0.0;
    private const double DISCHARGE_R = 1.0;
    private const double DISCHARGE_G = 0.4;
    private const double DISCHARGE_B = 0.0;

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

    public void set_chart_mode (int mode) {
        chart_mode = mode;
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
            draw_curve (cr, width, height);
        }

        return true;
    }

    private void draw_background (Cairo.Context cr, int width, int height) {
        cr.set_source_rgb (1.0, 1.0, 1.0);
        cr.rectangle (0, 0, width, height);
        cr.fill ();
    }

    private void draw_grid (Cairo.Context cr, int width, int height) {
        cr.set_source_rgb (0.92, 0.92, 0.92);
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
        cr.set_source_rgb (0.3, 0.3, 0.3);
        cr.set_line_width (1.0);

        // 左轴
        cr.move_to (PADDING_LEFT, PADDING_TOP);
        cr.line_to (PADDING_LEFT, height - PADDING_BOTTOM);
        cr.stroke ();

        // 右轴
        cr.move_to (width - PADDING_RIGHT, PADDING_TOP);
        cr.line_to (width - PADDING_RIGHT, height - PADDING_BOTTOM);
        cr.stroke ();

        // 底轴
        cr.move_to (PADDING_LEFT, height - PADDING_BOTTOM);
        cr.line_to (width - PADDING_RIGHT, height - PADDING_BOTTOM);
        cr.stroke ();

        // 左轴标签
        cr.set_font_size (10);
        double max_value = get_max_value ();

        if (chart_mode == 0) {
            // 电量：0-100%
            cr.set_source_rgb (CAPACITY_R, CAPACITY_G, CAPACITY_B);
            for (int i = 0; i <= 4; i++) {
                int value = 100 - i * 25;
                double y = PADDING_TOP + (height - PADDING_TOP - PADDING_BOTTOM) * i / 4.0;
                cr.move_to (5, y + 4);
                cr.show_text ("%d%%".printf (value));
            }
        } else {
            // 功率：0-max W
            cr.set_source_rgb (chart_mode == 1 ? CHARGE_R : DISCHARGE_R,
                              chart_mode == 1 ? CHARGE_G : DISCHARGE_G,
                              chart_mode == 1 ? CHARGE_B : DISCHARGE_B);
            for (int i = 0; i <= 4; i++) {
                double value = max_value * (4 - i) / 4.0;
                double y = PADDING_TOP + (height - PADDING_TOP - PADDING_BOTTOM) * i / 4.0;
                cr.move_to (5, y + 4);
                cr.show_text ("%.0fW".printf (value));
            }
        }

        draw_time_labels (cr, width, height);
    }

    private double get_max_value () {
        double max_val = 0;

        if (chart_mode == 0) {
            return 100;
        }

        for (int i = 0; i < data.get_length (); i++) {
            var entry = data.get_object_element (i);
            double power = entry.has_member ("power_watts") ? entry.get_double_member ("power_watts") : 0;
            string status = entry.get_string_member ("status");

            if (chart_mode == 1 && status == "Charging") {
                if (power > max_val) max_val = power;
            } else if (chart_mode == 2 && status == "Discharging") {
                if (power > max_val) max_val = power;
            }
        }

        return max_val * 1.1 > 0 ? max_val * 1.1 : 50;
    }

    private void draw_time_labels (Cairo.Context cr, int width, int height) {
        int64 now = get_now ();
        int64 start_time = now - (time_range_hours * 3600);

        cr.set_source_rgb (0.4, 0.4, 0.4);
        cr.set_font_size (10);
        for (int i = 0; i <= 6; i++) {
            double x = PADDING_LEFT + (width - PADDING_LEFT - PADDING_RIGHT) * i / 6.0;
            int64 t = start_time + (time_range_hours * 3600 * i / 6);
            string label = format_time (t);
            cr.move_to (x - 15, height - PADDING_BOTTOM + 15);
            cr.show_text (label);
        }
    }

    private void draw_curve (Cairo.Context cr, int width, int height) {
        if (data.get_length () < 2) return;

        double plot_width = width - PADDING_LEFT - PADDING_RIGHT;
        double plot_height = height - PADDING_TOP - PADDING_BOTTOM;

        int64 now = get_now ();
        int64 start_time = now - (time_range_hours * 3600);

        double max_value = get_max_value ();
        if (max_value <= 0) return;

        // 设置曲线颜色
        switch (chart_mode) {
            case 0:
                cr.set_source_rgb (CAPACITY_R, CAPACITY_G, CAPACITY_B);
                break;
            case 1:
                cr.set_source_rgb (CHARGE_R, CHARGE_G, CHARGE_B);
                break;
            case 2:
                cr.set_source_rgb (DISCHARGE_R, DISCHARGE_G, DISCHARGE_B);
                break;
        }

        cr.set_line_width (2.0);

        // 收集数据点
        var points_x = new double[data.get_length ()];
        var points_y = new double[data.get_length ()];
        int valid_count = 0;

        for (int i = 0; i < data.get_length (); i++) {
            var entry = data.get_object_element (i);
            int64 timestamp = entry.get_int_member ("timestamp");
            string status = entry.get_string_member ("status");

            double value = 0;
            if (chart_mode == 0) {
                value = entry.get_int_member ("capacity");
            } else if (chart_mode == 1) {
                if (status != "Charging") continue;
                value = entry.has_member ("power_watts") ? entry.get_double_member ("power_watts") : 0;
            } else if (chart_mode == 2) {
                if (status != "Discharging") continue;
                value = entry.has_member ("power_watts") ? entry.get_double_member ("power_watts") : 0;
            }

            double x = PADDING_LEFT + plot_width * (timestamp - start_time) / (double) (time_range_hours * 3600);
            double y;
            if (chart_mode == 0) {
                y = PADDING_TOP + plot_height * (1.0 - value / 100.0);
            } else {
                y = PADDING_TOP + plot_height * (1.0 - value / max_value);
            }

            if (x >= PADDING_LEFT) {
                points_x[valid_count] = x;
                points_y[valid_count] = y;
                valid_count++;
            }
        }

        if (valid_count < 2) return;

        // 绘制平滑曲线（贝塞尔）
        cr.move_to (points_x[0], points_y[0]);

        for (int i = 1; i < valid_count; i++) {
            double x0 = points_x[i - 1];
            double y0 = points_y[i - 1];
            double x1 = points_x[i];
            double y1 = points_y[i];

            double mid_x = (x0 + x1) / 2.0;

            cr.curve_to (mid_x, y0, mid_x, y1, x1, y1);
        }
        cr.stroke ();

        // 绘制数据点
        for (int i = 0; i < valid_count; i++) {
            cr.arc (points_x[i], points_y[i], 3, 0, 2 * Math.PI);
            cr.fill ();
        }
    }
}
