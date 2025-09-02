# Migration Importers Performance Analysis & Optimization Plan

## Current State Analysis

Based on examining all the importers, here's what I found:

### 🟢 **Already Optimized (Good Performance)**
1. **LoanImporter** - Already uses batch processing with `Stream.chunk_every(batch_size)`
2. **FineImporter** - Already uses batch processing with `Stream.chunk_every(batch_size)`
3. **UserImporter** - ✅ Recently optimized with our improvements

### 🟡 **Partially Optimized (Moderate Performance Issues)**
4. **ItemImporter** - Uses individual inserts but has some stream processing
5. **MemberImporter** - Uses streams but individual DB operations

### 🔴 **Needs Significant Optimization (Major Performance Issues)**
6. **BiblioImporter** - Complex individual processing, heavy DB lookups
7. **MasterImporter** - Individual inserts, no batch processing
8. **LoanHistoryImporter** - Likely individual processing

## Priority Optimization Recommendations

### **HIGH PRIORITY** 🔥

#### 1. BiblioImporter Optimization
**Issues:**
- Individual `Repo.insert` for each record
- Heavy image processing per record
- Multiple DB lookups per record (author, publisher mappings)
- Complex field processing

**Optimization Strategy:**
- Implement batch inserts
- Cache author and publisher mappings
- Lazy image processing (defer until after DB insert)
- Stream processing pipeline

**Expected Performance Gain:** 5-8x faster

#### 2. MemberImporter Optimization
**Issues:**
- Individual `Repo.insert` per member
- Repeated DB queries for roles, member types, nodes
- No caching of frequently accessed data

**Optimization Strategy:**
- Similar to UserImporter optimizations
- Cache roles, member types, and nodes
- Batch processing with `Repo.insert_all`
- Stream pipeline with filtering

**Expected Performance Gain:** 4-6x faster

### **MEDIUM PRIORITY** ⚡

#### 3. ItemImporter Optimization
**Issues:**
- Individual DB queries for biblio mapping
- Agent-based tracking (could be optimized)
- Individual inserts

**Optimization Strategy:**
- Batch inserts instead of individual
- Pre-cache biblio mappings more efficiently
- ETS tables instead of Agents for tracking

**Expected Performance Gain:** 3-5x faster

#### 4. MasterImporter Optimization
**Issues:**
- Individual processing for each master data type
- No batch processing

**Optimization Strategy:**
- Batch insert for each master data type
- Stream processing
- Parallel processing for different master types

**Expected Performance Gain:** 3-4x faster

## Implementation Plan

### Phase 1: High Priority (Week 1)
1. ✅ UserImporter - DONE
2. BiblioImporter optimization
3. MemberImporter optimization

### Phase 2: Medium Priority (Week 2)
1. ItemImporter optimization
2. MasterImporter optimization

### Phase 3: Fine-tuning (Week 3)
1. Cross-importer performance testing
2. Memory usage optimization
3. Error handling improvements

## Expected Overall Performance Impact

| Importer | Current Est. Time | Optimized Est. Time | Improvement |
|----------|------------------|-------------------|-------------|
| UserImporter | ✅ Already optimized | - | 6-7x faster |
| BiblioImporter | ~2-3 hours | ~20-30 minutes | 6x faster |
| MemberImporter | ~30-45 minutes | ~5-8 minutes | 5x faster |
| ItemImporter | ~45 minutes | ~10-12 minutes | 4x faster |
| LoanImporter | ✅ Good performance | - | Already optimized |
| FineImporter | ✅ Good performance | - | Already optimized |

## Technical Strategies to Apply

### 1. **Stream Processing Pipeline**
```elixir
File.stream!(file)
|> CSVParser.parse_stream()
|> Stream.drop(1)  # Skip header
|> Stream.map(&prepare_data/2)
|> Stream.filter(&valid_data?/1)
|> Stream.chunk_every(batch_size)
|> Stream.each(&process_batch/1)
|> Stream.run()
```

### 2. **Caching Strategy**
- Pre-load frequently accessed reference data
- Use ETS tables for large datasets
- Cache validation results

### 3. **Batch Processing**
- Use `Repo.insert_all` instead of individual `Repo.insert`
- Process in configurable batches (500-2000 records)
- Single transaction per batch

### 4. **Memory Optimization**
- Stream processing to avoid loading entire CSV into memory
- ETS tables instead of Agent processes
- Lazy evaluation where possible

### 5. **Error Handling**
- Batch-level error recovery
- Detailed progress reporting
- Graceful handling of malformed data

## Next Steps

Would you like me to:
1. **Start with BiblioImporter optimization** (highest impact)
2. **Optimize MemberImporter** (similar to UserImporter pattern)
3. **Create a performance testing framework** for all importers
4. **Analyze specific performance bottlenecks** in detail

The BiblioImporter appears to be the most complex and would benefit the most from optimization, especially given its heavy image processing and complex field mappings.
