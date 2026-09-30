SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET character_set_client = utf8mb4;
SET character_set_connection = utf8mb4;
SET character_set_results = utf8mb4;

-- ---------------------------------------------------------------------
-- 电子装配厂 · SMT 工单与齐套装配管理
-- 库名 electronics_assembly；application.yml 里 ddl-auto: none，表结构全部由本文件在 MySQL 镜像构建期导入。
-- 注意：mysql 容器是 UTC，种子数据里的时间一律写 UTC_TIMESTAMP() + INTERVAL 8 HOUR。

CREATE DATABASE IF NOT EXISTS electronics_assembly
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE electronics_assembly;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS inspection;
DROP TABLE IF EXISTS smt_step;
DROP TABLE IF EXISTS bom_item;
DROP TABLE IF EXISTS component;
DROP TABLE IF EXISTS work_order;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------- 生产工单 ----------------
CREATE TABLE work_order (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_no      VARCHAR(32) NOT NULL UNIQUE,
    product_model VARCHAR(48) NOT NULL,
    plan_qty      INT         NOT NULL COMMENT '计划投产板数',
    done_qty      INT         NOT NULL DEFAULT 0,
    priority      VARCHAR(8)  NOT NULL COMMENT '高/中/低',
    status        VARCHAR(16) NOT NULL COMMENT '待投产/贴片中/待检验/已完成/已取消',
    due_date      DATE,
    created_at    DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------- 物料台账 ----------------
CREATE TABLE component (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    part_no      VARCHAR(32) NOT NULL UNIQUE,
    part_name    VARCHAR(64) NOT NULL,
    package_type VARCHAR(16) NOT NULL COMMENT '0201/0402/0603/0805/SOT/QFP/BGA',
    stock_qty    INT         NOT NULL DEFAULT 0 COMMENT '现有库存（颗）',
    feed_slot    VARCHAR(16) COMMENT '飞达位',
    status       VARCHAR(16) NOT NULL COMMENT '正常/缺料/停用'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------- BOM：某机型单板用料 ----------------
CREATE TABLE bom_item (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_model VARCHAR(48) NOT NULL,
    part_no       VARCHAR(32) NOT NULL,
    unit_qty      INT         NOT NULL COMMENT '单板用量（颗）',
    UNIQUE KEY uk_bom (product_model, part_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------- SMT 工序流转 ----------------
CREATE TABLE smt_step (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id    BIGINT      NOT NULL,
    step_name   VARCHAR(16) NOT NULL COMMENT '上料/贴片/回流焊/AOI/目检',
    status      VARCHAR(16) NOT NULL COMMENT '待执行/进行中/已完成',
    operator    VARCHAR(32),
    started_at  DATETIME,
    finished_at DATETIME,
    CONSTRAINT fk_step_order FOREIGN KEY (order_id) REFERENCES work_order (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------- 质检与返修 ----------------
CREATE TABLE inspection (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id      BIGINT      NOT NULL,
    step_name     VARCHAR(16) NOT NULL,
    defect_type   VARCHAR(16) NOT NULL COMMENT '少件/偏移/虚焊/连锡/反向',
    defect_points INT         NOT NULL DEFAULT 0 COMMENT '不良点数，超过 12 判废',
    sample_qty    INT         NOT NULL DEFAULT 0 COMMENT '抽检板数',
    verdict       VARCHAR(16) NOT NULL COMMENT '合格/返修/判废',
    inspector     VARCHAR(32),
    repair_done   TINYINT(1)  NOT NULL DEFAULT 0 COMMENT '返修是否闭环',
    checked_at    DATETIME,
    CONSTRAINT fk_insp_order FOREIGN KEY (order_id) REFERENCES work_order (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- 种子数据
-- =====================================================================

INSERT INTO work_order (order_no, product_model, plan_qty, done_qty, priority, status, due_date, created_at) VALUES
('WO-2026001', 'MODEL-A', 500,  0, '高', '待投产', UTC_TIMESTAMP() + INTERVAL 8 HOUR + INTERVAL  2 DAY, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 2 DAY),
('WO-2026002', 'MODEL-A', 300, 300, '中', '已完成', UTC_TIMESTAMP() + INTERVAL 8 HOUR + INTERVAL  5 DAY, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 4 DAY),
('WO-2026003', 'MODEL-B', 800, 260, '高', '贴片中', UTC_TIMESTAMP() + INTERVAL 8 HOUR + INTERVAL  1 DAY, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 3 DAY),
('WO-2026004', 'MODEL-B', 200,   0, '低', '待投产', UTC_TIMESTAMP() + INTERVAL 8 HOUR + INTERVAL 12 DAY, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 1 DAY),
('WO-2026005', 'MODEL-C', 400, 400, '中', '待检验', UTC_TIMESTAMP() + INTERVAL 8 HOUR + INTERVAL  3 DAY, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 2 DAY);

-- 物料：RC-0402-10K 库存偏紧，MODEL-A 500 板 × 8 颗 = 4000 > 库存 3200 → 齐套不通过
INSERT INTO component (part_no, part_name, package_type, stock_qty, feed_slot, status) VALUES
('RC-0402-10K', '10K 电阻',      '0402', 3200,  'F01', '正常'),
('CC-0402-100N', '100nF 电容',   '0402', 9000,  'F02', '正常'),
('IC-SOT-23-AMS', 'AMS1117 稳压', 'SOT',  1200,  'F03', '正常'),
('IC-QFP-MCU',  'MCU 主控',      'QFP',   850,  'F04', '正常'),
('IC-BGA-FPGA', 'FPGA 芯片',     'BGA',    90,  'F05', '缺料'),
('RC-0603-1K',  '1K 电阻',       '0603', 6000,  'F06', '正常'),
('LED-0805-R',  '红色指示灯',    '0805', 1500,  'F07', '正常'),
('CON-0201-4P', '4P 排针',       '0201',   40,  'F08', '停用');

-- BOM：MODEL-A 用前四种；MODEL-B 用 MCU + 电阻 + LED；MODEL-C 用 FPGA 等
INSERT INTO bom_item (product_model, part_no, unit_qty) VALUES
('MODEL-A', 'RC-0402-10K',   8),
('MODEL-A', 'CC-0402-100N', 12),
('MODEL-A', 'IC-SOT-23-AMS', 1),
('MODEL-A', 'IC-QFP-MCU',    1),
('MODEL-B', 'RC-0603-1K',    6),
('MODEL-B', 'IC-QFP-MCU',    1),
('MODEL-B', 'LED-0805-R',    2),
('MODEL-C', 'IC-BGA-FPGA',   1),
('MODEL-C', 'CC-0402-100N',  9),
('MODEL-C', 'RC-0402-10K',   4);

-- 工序：WO-2026003（贴片中）五道工序都在推进；WO-2026001 尚未开工
INSERT INTO smt_step (order_id, step_name, status, operator, started_at, finished_at) VALUES
(3, '上料',   '已完成', '王强', UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 20 HOUR, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 19 HOUR),
(3, '贴片',   '进行中', '李敏', UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 18 HOUR, NULL),
(3, '回流焊', '待执行', NULL,   NULL, NULL),
(3, 'AOI',    '待执行', NULL,   NULL, NULL),
(3, '目检',   '待执行', NULL,   NULL, NULL),
(5, '上料',   '已完成', '王强', UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 30 HOUR, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 29 HOUR),
(5, '贴片',   '已完成', '李敏', UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 28 HOUR, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 26 HOUR),
(5, '回流焊', '已完成', '赵磊', UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 25 HOUR, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 24 HOUR),
(5, 'AOI',    '已完成', '孙悦', UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 23 HOUR, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 22 HOUR),
(5, '目检',   '待执行', NULL,   NULL, NULL);

-- 质检：第 2 条不良 15 点已判废；第 4 条不良 5 点判返修且未闭环
INSERT INTO inspection (order_id, step_name, defect_type, defect_points, sample_qty, verdict, inspector, repair_done, checked_at) VALUES
(2, 'AOI',  '偏移',  3,  50, '返修', '孙悦', 1, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 1 DAY),
(2, 'AOI',  '连锡', 15,  50, '判废', '孙悦', 0, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 1 DAY),
(5, 'AOI',  '虚焊',  4,  40, '返修', '孙悦', 1, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 6 HOUR),
(5, '目检', '少件',  5,  40, '返修', '周涛', 0, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 2 HOUR),
(3, 'AOI',  '反向',  2,  30, '合格', '孙悦', 1, UTC_TIMESTAMP() + INTERVAL 8 HOUR - INTERVAL 3 HOUR);
