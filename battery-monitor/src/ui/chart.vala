using Gtk;
using Cairo;

public class BatteryChart : Gtk.DrawingArea {
    private Json.Array data;
    private int time_range_hours = 1;
    private bool show_power_curve = true;
    private const int PADDING_LEFT = 50;
    private const int PADDING_RIGHT = 50;
    private const int PADDING_TOP = 30;
    private const int PADDING_BOTTOM = 30;

    // 电量曲线颜色（蓝色）
    private const double CAPACITY_R = 0.2;
    private const double CAPACITY_G = 0.6;
    private const double CAPACITY_B = 1.0;

    // 功率曲线颜色（橙色）
    private const double POWER_R = 1.0;
    private const double POWER_G = 0.6;
    private const double POWER_B = 0.0;

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

    public void set_show_power (bool show) {
        show_power_curve = show;
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
        draw_legend (cr, width, height);

        if (data.get_length () > 1) {
            draw_capacity_curve (cr, width, height);
            if (show_power_curve) {
                draw_power_curve (cr, width, height);
            }
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

        // 左轴（电量）
        cr.move_to (PADDING_LEFT, PADDING_TOP);
        cr.line_to (PADDING_LEFT, height - PADDING_BOTTOM);
        cr.stroke ();

        // 右轴（功率）
        cr.move_to (width - PADDING_RIGHT, PADDING_TOP);
        cr.line_to (width - PADDING_RIGHT, height - PADDING_BOTTOM);
        cr.stroke ();

        // 底轴
        cr.move_to (PADDING_LEFT, height - PADDING_BOTTOM);
        cr.line_to (width - PADDING_RIGHT, height - PADDING_BOTTOM);
        cr.stroke ();

        // 左轴标签（电量 0-100%）
        cr.set_font_size (10);
        cr.set_source_rgb (CAPACITY_R, CAPACITY_G, CAPACITY_B);
        for (int i = 0; i <= 4; i++) {
            int value = 100 - i * 25;
            double y = PADDING_TOP + (height - PADDING_TOP - PADDING_BOTTOM) * i / 4.0;
            cr.move_to (5, y + 4);
            cr.show_text ("%d%%".printf (value));
        }

        // 右轴标签（功率）
        if (show_power_curve) {
            cr.set_source_rgb (POWER_R, POWER_G, POWER_B);
            double max_power = get_max_power ();
            if (max_power <= 0) max_power = 50;
            for (int i = 0; i <= 4; i++) {
                double value = max_power * (4 - i) / 4.0;
                double y = PADDING_TOP + (height - PADDING_TOP - PADDING_BOTTOM) * i / 4.0;
                cr.move_to (width - PADDING_RIGHT + 5, y + 4);
                cr.show_text ("%.0fW".printf (value));
            }
        }

        draw_time_labels (cr, width, height);
    }

    private double get_max_power () {
        double max_power = 0;
        for (int i = 0; i < data.get_length (); i++) {
            var entry = data.get_object_element (i);
            if (entry.has_member ("power_watts")) {
                double power = entry.get_double_member ("power_watts");
                if (power > max_power) max_power = power;
            }
        }
        return max_power * 1.1 > 0 ? max_power * 1.1 : 50;
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

    private void draw_legend (Cairo.Context cr, int width, int height) {
        int legend_x = PADDING_LEFT + 10;
        int legend_y = PADDING_TOP + 5;

        cr.set_font_size (10);

        // 电量图例
        cr.set_source_rgb (CAPACITY_R, CAPACITY_G, CAPACITY_B);
        cr.rectangle (legend_x, legend_y, 15, 3);
        cr.fill ();
        cr.move_to (legend_x + 20, legend_y + 5);
        cr.show_text ("电量");

        if (show_power_curve) {
            // 功率图例
            cr.set_source_rgb (POWER_R, POWER_G, POWER_B);
            cr.rectangle (legend_x + 60, legend_y, 15, 3);
            cr.fill ();
            cr.move_to (legend_x + 80, legend_y + 5);
            cr.show_text ("功率");
        }
    }

    private void draw_capacity_curve (Cairo.Context cr, int width, int height) {
        if (data.get_length () < 2) return;

        double plot_width = width - PADDING_LEFT - PADDING_RIGHT;
        double plot_height = height - PADDING_TOP - PADDING_BOTTOM;

        int64 now = get_now ();
        int64 start_time = now - (time_range_hours * 3600);

        // 收集数据点
        var points_x = new double[data.get_length ()];
        var points_y = new double[data.get_length ()];
        int valid_count = 0;

        for (int i = 0; i < data.get_length (); i++) {
            var entry = data.get_object_element (i);
            int64 timestamp = entry.get_int_member ("timestamp");
            int capacity = (int) entry.get_int_member ("capacity");

            double x = PADDING_LEFT + plot_width * (timestamp - start_time) / (double) (time_range_hours * 3600);
            double y = PADDING_TOP + plot_height * (1.0 - capacity / 100.0);

            if (x >= PADDING_LEFT) {
                points_x[valid_count] = x;
                points_y[valid_count] = y;
                valid_count++;
            }
        }

        if (valid_count < 2) return;

        // 绘制平滑曲线（贝塞尔）
        cr.set_source_rgb (CAPACITY_R, CAPACITY_G, CAPACITY_B);
        cr.set_line_width (2.0);

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
        cr.set_source_rgb (CAPACITY_R, CAPACITY_G, CAPACITY_B);
        for (int i = 0; i < valid_count; i++) {
            cr.arc (points_x[i], points_y[i], 3, 0, 2 * Math.PI);
            cr.fill ();
        }
    }

    private void draw_power_curve (Cairo.Context cr, int width, int height) {
        if (data.get_length () < 2) return;

        double plot_width = width - PADDING_LEFT - PADDING_RIGHT;
        double plot_height = height - PADDING_TOP - PADDING_BOTTOM;

        int64 now = get_now ();
        int64 start_time = now - (time_range_hours * 3600);

        double max_power = get_max_power ();
        if (max_power <= 0) return;

        // 收集数据点
        var points_x = new double[data.get_length ()];
        var points_y = new double[data.get_length ()];
        int valid_count = 0;

        for (int i = 0; i < data.get_length (); i++) {
            var entry = data.get_object_element (i);
            int64 timestamp = entry.get_int_member ("timestamp");
            double power = entry.has_member ("power_watts") ? entry.get_double_member ("power_watts") : 0;

            double x = PADDING_LEFT + plot_width * (timestamp - start_time) / (double) (time_range_hours * 3600);
            double y = PADDING_TOP + plot_height * (1.0 - power / max_power);

            if (x >= PADDING_LEFT) {
                points_x[valid_count] = x;
                points_y[valid_count] = y;
                valid_count++;
            }
        }

        if (valid_count < 2) return;

        // 绘制平滑曲线（贝塞尔）
        cr.set_source_rgb (POWER_R, POWER_G, POWER_B);
        cr.set_line_width (2.0);
        double[] dash = {5.0, 3.0};
        cr.set_dash (dash, 0);

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
        cr.set_dash (null, 0);

        // 绘制数据点
        cr.set_source_rgb (POWER_R, POWER_G, POWER_B);
        for (int i = 0; i < valid_count; i++) {
            cr.arc (points_x[i], points_y[i], 3, 0, 2 * Math.PI);
            cr.fill ();
        }
    }
}
