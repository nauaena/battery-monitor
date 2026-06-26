public class BatteryData : Object {
    // 基本信息
    public int capacity { get; set; default = 0; }
    public string status { get; set; default = "Unknown"; }
    public string manufacturer { get; set; default = ""; }
    public string model_name { get; set; default = ""; }
    public string technology { get; set; default = ""; }
    public string charge_type { get; set; default = ""; }

    // 功率信息 (单位已转换)
    public double power_watts { get; set; default = 0; }
    public double voltage_volts { get; set; default = 0; }
    public double current_amps { get; set; default = 0; }
    public bool is_charging {
        get { return status == "Charging"; }
    }
    // 显示功率（放电为正，充电为负）
    public double display_power_watts {
        get {
            if (status == "Charging") return -power_watts;
            return power_watts;
        }
    }

    // 输入电压电流（充电时）
    public double input_voltage { get; set; default = 0; }
    public double input_current { get; set; default = 0; }

    // 设计电压
    public double voltage_min_design { get; set; default = 0; }

    // 容量信息 (Wh)
    public double energy_now { get; set; default = 0; }
    public double energy_full { get; set; default = 0; }
    public double energy_full_design { get; set; default = 0; }

    // 健康度
    public double health_percent {
        get {
            if (energy_full_design > 0)
                return (energy_full / energy_full_design) * 100;
            return 0;
        }
    }

    public int cycle_count { get; set; default = 0; }

    private string battery_path = "/sys/class/power_supply/BAT0";

    public bool update () {
        if (!FileUtils.test (battery_path, FileTest.EXISTS)) {
            return false;
        }

        capacity = read_int ("capacity");
        status = read_string ("status");
        manufacturer = read_string ("manufacturer");
        model_name = read_string ("model_name");
        technology = read_string ("technology");
        cycle_count = read_int ("cycle_count");
        charge_type = read_string ("charge_types");

        power_watts = read_long ("power_now") / 1000000.0;
        voltage_volts = read_long ("voltage_now") / 1000000.0;

        // 尝试读取 current_now，如果不存在则通过功率/电压计算
        long current_raw = read_long ("current_now");
        if (current_raw > 0) {
            current_amps = current_raw / 1000000.0;
        } else if (voltage_volts > 0 && power_watts > 0) {
            current_amps = power_watts / voltage_volts;
        } else {
            current_amps = 0;
        }

        voltage_min_design = read_long ("voltage_min_design") / 1000000.0;

        // 输入电压电流（从 uevent 读取）
        input_voltage = read_from_uevent ("POWER_SUPPLY_VOLTAGE_NOW") / 1000000.0;
        input_current = read_from_uevent ("POWER_SUPPLY_CURRENT_NOW") / 1000000.0;

        energy_now = read_long ("energy_now") / 1000000.0;
        energy_full = read_long ("energy_full") / 1000000.0;
        energy_full_design = read_long ("energy_full_design") / 1000000.0;

        return true;
    }

    public string get_status_text () {
        switch (status) {
            case "Charging": return "充电中";
            case "Discharging": return "放电中";
            case "Full": return "已充满";
            case "Not charging": return "未充电";
            default: return "未知";
        }
    }

    public string get_health_status () {
        if (health_percent > 90) return "优秀";
        if (health_percent > 80) return "良好";
        if (health_percent > 70) return "一般";
        return "需关注";
    }

    public string get_estimated_time () {
        if (power_watts <= 0) return "无法估算";

        double remaining_hours;
        if (status == "Charging") {
            remaining_hours = (energy_full - energy_now) / power_watts;
            int hours = (int) remaining_hours;
            int minutes = (int) ((remaining_hours - hours) * 60);
            return "预计还需 %d小时%d分钟充满".printf (hours, minutes);
        } else if (status == "Discharging") {
            remaining_hours = energy_now / power_watts;
            int hours = (int) remaining_hours;
            int minutes = (int) ((remaining_hours - hours) * 60);
            return "预计还可使用 %d小时%d分钟".printf (hours, minutes);
        }
        return "无法估算";
    }

    private int read_int (string filename) {
        string filepath = Path.build_filename (battery_path, filename);
        try {
            string contents;
            FileUtils.get_contents (filepath, out contents);
            return int.parse (contents.strip ());
        } catch (Error e) {
            return 0;
        }
    }

    private long read_long (string filename) {
        string filepath = Path.build_filename (battery_path, filename);
        try {
            string contents;
            FileUtils.get_contents (filepath, out contents);
            return long.parse (contents.strip ());
        } catch (Error e) {
            return 0;
        }
    }

    private string read_string (string filename) {
        string filepath = Path.build_filename (battery_path, filename);
        try {
            string contents;
            FileUtils.get_contents (filepath, out contents);
            return contents.strip ();
        } catch (Error e) {
            return "";
        }
    }

    private double read_from_uevent (string key) {
        string uevent_path = Path.build_filename (battery_path, "uevent");
        try {
            string contents;
            FileUtils.get_contents (uevent_path, out contents);
            string[] lines = contents.split ("\n");
            foreach (string line in lines) {
                if (line.has_prefix (key + "=")) {
                    return double.parse (line.substring (key.length + 1));
                }
            }
        } catch (Error e) {
        }
        return 0;
    }

    public string get_charge_type_text () {
        if (charge_type == "") return "未知";
        if (charge_type.contains ("Fast")) return "快速充电";
        if (charge_type.contains ("Standard")) return "标准充电";
        if (charge_type.contains ("HV")) return "高压快充";
        return charge_type;
    }
}
