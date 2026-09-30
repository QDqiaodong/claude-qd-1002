package com.electronics.assembly.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.electronics.assembly.entity.WorkOrder;

/**
 * 生产工单 Repository：常规 JPA 能力 + {@link WorkOrderRepositoryCustom} 手写的齐套查询。
 */
public interface WorkOrderRepository extends JpaRepository<WorkOrder, Long>, WorkOrderRepositoryCustom {

    Optional<WorkOrder> findByOrderNo(String orderNo);

    List<WorkOrder> findByStatus(String status);

    List<WorkOrder> findByProductModel(String productModel);
}
